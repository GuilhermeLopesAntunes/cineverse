import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { db } from '../../prisma/db';
import { SeatLockService } from '../seats/seat-lock.service';
import { CreateOrderDto } from './dto/create-order.dto';

export interface OrderItemResponse {
  seatId: number;
  comboItemId: number | null;
}

export interface OrderResponse {
  id: number;
  userId: number;
  sessionId: number;
  status: string;
  totalAmountCents: number;
  createdAt: string;
  items: OrderItemResponse[];
}

export interface PaginatedOrders {
  items: OrderResponse[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

const ORDER_FIELDS = [
  'id',
  'userId',
  'sessionId',
  'status',
  'totalAmountCents',
  'createdAt',
] as const;

// "Checkout individual em até 3 passos" (BE-24, RF-08): (1) lock the seat(s)
// (BE-23), (2) create the order (this service), (3) pay (BE-27+, not built
// yet). Nothing here releases the Redis lock — it keeps protecting the seat
// through the pending-order window; only payment confirmation converts it
// into a real sale (ARQUITETURA_BACKEND.md § 5, still to come).
@Injectable()
export class OrdersService {
  constructor(private readonly seatLockService: SeatLockService) {}

  async create(userId: number, dto: CreateOrderDto): Promise<OrderResponse> {
    const session = await db.orm.public.Session.where({
      id: dto.sessionId,
    }).first();
    if (!session) {
      throw new NotFoundException(`Sessão ${dto.sessionId} não encontrada`);
    }

    const seatIds = dto.items.map((item) => item.seatId);

    // Ownership check doubles as existence validation: a seat id that never
    // belonged to this session could never have been locked in the first
    // place (SeatLockService.lockSeats syncs with the partner gateway,
    // which validates seat-in-session — BE-20/21), so it can never show up
    // as "held by this user" either.
    const heldSeatIds = await this.seatLockService.getSeatIdsHeldBy(
      dto.sessionId,
      seatIds,
      userId,
    );
    const notHeld = seatIds.filter((id) => !heldSeatIds.includes(id));
    if (notHeld.length > 0) {
      throw new ConflictException(
        `Reserve o(s) assento(s) antes de finalizar a compra: ${notHeld.join(', ')}`,
      );
    }

    const comboPriceById = await this.validateCombos(session.roomId, dto.items);

    const totalAmountCents = dto.items.reduce((sum, item) => {
      const comboPrice =
        item.comboItemId !== undefined
          ? (comboPriceById.get(item.comboItemId) ?? 0)
          : 0;
      return sum + session.priceCents + comboPrice;
    }, 0);

    return db.transaction(async (tx) => {
      const order = await tx.orm.public.Order.select(...ORDER_FIELDS).create({
        userId,
        sessionId: dto.sessionId,
        status: 'pending',
        totalAmountCents,
      });
      for (const item of dto.items) {
        await tx.orm.public.OrderItem.create({
          orderId: order.id,
          seatId: item.seatId,
          comboItemId: item.comboItemId ?? null,
        });
      }
      return {
        ...order,
        items: dto.items.map((item) => ({
          seatId: item.seatId,
          comboItemId: item.comboItemId ?? null,
        })),
      };
    });
  }

  async findOne(orderId: number, userId: number): Promise<OrderResponse> {
    const order = await db.orm.public.Order.where({ id: orderId })
      .select(...ORDER_FIELDS)
      .first();
    if (!order) {
      throw new NotFoundException(`Pedido ${orderId} não encontrado`);
    }
    if (order.userId !== userId) {
      throw new ForbiddenException('Você não tem acesso a esse pedido');
    }

    const items = await db.orm.public.OrderItem.where({ orderId })
      .select('seatId', 'comboItemId')
      .all();
    return { ...order, items };
  }

  async list(
    userId: number,
    page: number,
    pageSize: number,
  ): Promise<PaginatedOrders> {
    const offset = (page - 1) * pageSize;
    const [orders, { total }] = await Promise.all([
      db.orm.public.Order.where({ userId })
        .select(...ORDER_FIELDS)
        .orderBy((o) => o.createdAt.desc())
        .offset(offset)
        .limit(pageSize)
        .all(),
      db.orm.public.Order.where({ userId }).aggregate((aggregate) => ({
        total: aggregate.count(),
      })),
    ]);

    const orderIds = orders.map((o) => o.id);
    const orderItems =
      orderIds.length === 0
        ? []
        : await db.orm.public.OrderItem.where((i) => i.orderId.in(orderIds))
            .select('orderId', 'seatId', 'comboItemId')
            .all();
    const itemsByOrder = new Map<number, OrderItemResponse[]>();
    for (const item of orderItems) {
      const items = itemsByOrder.get(item.orderId) ?? [];
      items.push({ seatId: item.seatId, comboItemId: item.comboItemId });
      itemsByOrder.set(item.orderId, items);
    }

    return {
      items: orders.map((o) => ({
        ...o,
        items: itemsByOrder.get(o.id) ?? [],
      })),
      page,
      pageSize,
      total,
      totalPages: Math.max(1, Math.ceil(total / pageSize)),
    };
  }

  // Every comboItemId in the request has to (a) exist and (b) belong to the
  // same partner as the session being checked out — a combo menu is
  // per-partner (ComboItem.partnerId), so a combo from a different cinema
  // can never attach to this order.
  private async validateCombos(
    roomId: number,
    items: { comboItemId?: number }[],
  ): Promise<Map<number, number>> {
    const comboItemIds = [
      ...new Set(
        items
          .map((item) => item.comboItemId)
          .filter((id): id is number => id !== undefined),
      ),
    ];
    if (comboItemIds.length === 0) {
      return new Map();
    }

    const room = await db.orm.public.Room.where({ id: roomId }).first();
    if (!room) {
      throw new NotFoundException(`Sala ${roomId} não encontrada`);
    }

    const combos = await db.orm.public.ComboItem.where((c) =>
      c.id.in(comboItemIds),
    )
      .select('id', 'partnerId', 'priceCents')
      .all();
    const comboById = new Map(combos.map((c) => [c.id, c]));

    const missing = comboItemIds.filter((id) => !comboById.has(id));
    if (missing.length > 0) {
      throw new NotFoundException(
        `Combo(s) não encontrado(s): ${missing.join(', ')}`,
      );
    }

    const wrongPartner = combos.filter((c) => c.partnerId !== room.partnerId);
    if (wrongPartner.length > 0) {
      throw new BadRequestException(
        `Combo(s) não pertencem ao parceiro dessa sessão: ${wrongPartner
          .map((c) => c.id)
          .join(', ')}`,
      );
    }

    return new Map(combos.map((c) => [c.id, c.priceCents]));
  }
}
