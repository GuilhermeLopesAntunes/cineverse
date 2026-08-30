import {
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { db } from '../../prisma/db';
import { PARTNER_TICKETING_GATEWAY } from '../partner-integration/partner-ticketing-gateway.interface';
import type { PartnerTicketingGateway } from '../partner-integration/partner-ticketing-gateway.interface';
import { SeatLockService } from '../seats/seat-lock.service';
import { TicketsService } from '../tickets/tickets.service';
import { CARD_GATEWAY_PROVIDER } from './card-gateway-provider.interface';
import type { CardGatewayProvider } from './card-gateway-provider.interface';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { PixWebhookDto } from './dto/pix-webhook.dto';
import { PIX_PROVIDER } from './pix-provider.interface';
import type { PixProvider } from './pix-provider.interface';
import type { TokenChargeProvider } from './token-charge-provider.interface';
import { WALLET_PROVIDER } from './wallet-provider.interface';
import type { WalletProvider } from './wallet-provider.interface';

export interface PaymentResponse {
  id: number;
  orderId: number;
  method: string;
  providerRef: string;
  status: string;
  createdAt: string;
}

const PAYMENT_FIELDS = [
  'id',
  'orderId',
  'method',
  'providerRef',
  'status',
  'createdAt',
] as const;

// Payment confirmation (BE-27/28/29 create the charge; this settles it) —
// arquitetura § 5, passo 6. "Confirmação" arrives two different ways
// depending on method: Pix's `handlePixWebhook` (async, provider calls back
// later) or synchronously inside `create()` for apple_pay/google_pay/card
// (the gateway/wallet already confirmed by the time `create()` returns).
// Either way, once a payment settles to `"paid"`, `settlePaidOrder` (BE-30)
// runs the same idempotent side effects: confirm the sale with the partner
// (`PartnerTicketingGateway.confirmSale`, itself contractually idempotent —
// safe against a retried webhook) and release the Redis seat lock, since
// the sale is now definitive and doesn't need that temporary hold anymore.
// Ticket + QR code generation (arquitetura § 5, passo 6, RF-13) also
// happens here, one per seat — BE-32.
@Injectable()
export class PaymentsService {
  constructor(
    @Inject(PIX_PROVIDER) private readonly pixProvider: PixProvider,
    @Inject(WALLET_PROVIDER) private readonly walletProvider: WalletProvider,
    @Inject(CARD_GATEWAY_PROVIDER)
    private readonly cardGatewayProvider: CardGatewayProvider,
    @Inject(PARTNER_TICKETING_GATEWAY)
    private readonly partnerGateway: PartnerTicketingGateway,
    private readonly seatLockService: SeatLockService,
    private readonly ticketsService: TicketsService,
  ) {}

  async create(
    userId: number,
    orderId: number,
    dto: CreatePaymentDto,
  ): Promise<PaymentResponse & { copyPasteCode?: string }> {
    const order = await this.findOrderOrThrow(orderId, userId);

    if (order.status !== 'pending') {
      throw new ConflictException(
        `Pedido ${orderId} não está aguardando pagamento (status: ${order.status})`,
      );
    }

    const existing = await db.orm.public.Payment.where({ orderId }).first();
    if (existing) {
      throw new ConflictException(
        `Pedido ${orderId} já tem um pagamento associado`,
      );
    }

    if (dto.method === 'pix') {
      const charge = await this.pixProvider.createCharge(
        order.totalAmountCents,
        String(orderId),
      );

      const payment = await db.orm.public.Payment.select(
        ...PAYMENT_FIELDS,
      ).create({
        orderId,
        method: dto.method,
        providerRef: charge.providerRef,
        status: 'pending',
      });

      return { ...payment, copyPasteCode: charge.copyPasteCode };
    }

    // Apple Pay / Google Pay (BE-28) and card (BE-29): the client already
    // tokenized the payment method (wallet authorization or Stripe
    // Elements/Pagar.me SDK) and handed us an opaque `token` — never card
    // data — so confirmation happens synchronously here, unlike Pix's async
    // webhook.
    const provider: TokenChargeProvider =
      dto.method === 'card' ? this.cardGatewayProvider : this.walletProvider;
    const chargeResult = await provider.charge(
      dto.token as string,
      order.totalAmountCents,
      String(orderId),
    );

    const payment = await db.transaction(async (tx) => {
      const created = await tx.orm.public.Payment.select(
        ...PAYMENT_FIELDS,
      ).create({
        orderId,
        method: dto.method,
        providerRef: chargeResult.providerRef,
        status: chargeResult.status,
      });
      if (chargeResult.status === 'paid') {
        await tx.orm.public.Order.where({ id: orderId }).update({
          status: 'paid',
        });
      }
      return created;
    });

    if (chargeResult.status === 'paid') {
      await this.settlePaidOrder(orderId);
    }

    return payment;
  }

  async listByOrder(
    userId: number,
    orderId: number,
  ): Promise<PaymentResponse[]> {
    await this.findOrderOrThrow(orderId, userId);
    return db.orm.public.Payment.where({ orderId })
      .select(...PAYMENT_FIELDS)
      .orderBy((p) => p.id.asc())
      .all();
  }

  // No auth guard on the controller side (this is a provider webhook, not a
  // logged-in user's request) — a real integration would verify the
  // provider's signature here instead; that's RD-03/the provider's own
  // homologation concern, not something to fake for a mock.
  async handlePixWebhook(dto: PixWebhookDto): Promise<void> {
    const payment = await db.orm.public.Payment.where({
      providerRef: dto.providerRef,
    }).first();
    if (!payment) {
      throw new NotFoundException(
        `Pagamento com referência ${dto.providerRef} não encontrado`,
      );
    }

    // Idempotent: a repeated webhook delivery for an already-settled
    // payment is a no-op, not an error — providers do retry.
    if (payment.status !== 'pending') {
      return;
    }

    await db.transaction(async (tx) => {
      await tx.orm.public.Payment.where({ id: payment.id }).update({
        status: dto.status,
      });
      if (dto.status === 'paid') {
        await tx.orm.public.Order.where({ id: payment.orderId }).update({
          status: 'paid',
        });
      }
    });

    if (dto.status === 'paid') {
      await this.settlePaidOrder(payment.orderId);
    }
  }

  // Idempotent by construction: `confirmSale` is a no-op on a retry (same
  // `orderId` already recorded as the buyer), and `releaseSeats` only
  // releases a lock this order's buyer still actually holds — calling this
  // twice for the same order (e.g. a duplicate Pix webhook delivery) does
  // nothing the second time.
  private async settlePaidOrder(orderId: number): Promise<void> {
    const order = await db.orm.public.Order.where({ id: orderId }).first();
    if (!order) {
      return;
    }

    const items = await db.orm.public.OrderItem.where({ orderId })
      .select('id', 'seatId')
      .all();
    const seatIds = items.map((item) => item.seatId);

    await Promise.all(
      seatIds.map((seatId) =>
        this.partnerGateway.confirmSale(order.sessionId, seatId, orderId),
      ),
    );

    // The Redis lock's job was only to protect the seat through the
    // "pending order" window (BE-23/24) — the sale is definitive now that
    // the partner confirmed it above, so this hold isn't needed anymore;
    // no reason to make it wait out the TTL.
    await this.seatLockService.releaseSeats(
      order.sessionId,
      seatIds,
      order.userId,
    );

    // One signed QR ticket per seat (RF-13, BE-32).
    await Promise.all(
      items.map((item) => this.ticketsService.generateForOrderItem(item.id)),
    );
  }

  private async findOrderOrThrow(orderId: number, userId: number) {
    const order = await db.orm.public.Order.where({ id: orderId }).first();
    if (!order) {
      throw new NotFoundException(`Pedido ${orderId} não encontrado`);
    }
    if (order.userId !== userId) {
      throw new ForbiddenException('Você não tem acesso a esse pedido');
    }
    return order;
  }
}
