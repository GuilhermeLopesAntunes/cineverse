import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ticketQrConfig } from '../../common/config/ticket-qr.config';
import { db } from '../../prisma/db';

export interface TicketResponse {
  id: number;
  orderItemId: number;
  qrCodePayload: string;
  status: string;
  usedAt: string | null;
  createdAt: string;
}

export interface TicketValidationResult {
  valid: boolean;
  // Set only when valid is false — same "expected, routine outcome, not an
  // error" convention as PartnerTicketingGateway's {success, reason?}
  // (partner-ticketing-gateway.interface.ts): a forged/expired/reused
  // ticket at the door is normal scanner traffic, not a server fault.
  reason?: string;
  ticket?: TicketResponse;
}

const TICKET_FIELDS = [
  'id',
  'orderItemId',
  'qrCodePayload',
  'status',
  'usedAt',
  'createdAt',
] as const;

// RF-13: one signed QR ticket per seat, generated once a payment settles
// (`PaymentsService.settlePaidOrder`, BE-30) — for every payment method,
// not just Pix. The payload IS the QR code's content: a JWT signed with
// `TICKET_QR_SECRET`, not a bare sequential id — unforgeable without the
// secret (ARQUITETURA_BACKEND.md § 3). It's also the validation endpoint's
// lookup key (`@unique` on `qrCodePayload`, RNF-12, BE-33): verify the
// signature first — a forged/garbage code is rejected without ever
// touching the DB — then a single indexed lookup by the exact string, no
// joins needed.
@Injectable()
export class TicketsService {
  constructor(private readonly jwtService: JwtService) {}

  async generateForOrderItem(orderItemId: number): Promise<TicketResponse> {
    const qrCodePayload = await this.jwtService.signAsync(
      { orderItemId },
      { secret: ticketQrConfig.secret },
    );

    return db.orm.public.Ticket.select(...TICKET_FIELDS).create({
      orderItemId,
      qrCodePayload,
      status: 'valid',
    });
  }

  // RF-14/RNF-12: reads + marks "used" in one shot. Verifies the signature
  // first — a forged/garbage payload is rejected without ever touching the
  // DB — then a single conditional UPDATE keyed on the unique
  // `qrCodePayload`, no joins. The `status: 'valid'` in the WHERE clause is
  // what's supposed to make this concurrency-safe: Postgres serializes
  // concurrent UPDATEs against the same row, so of two simultaneous scans
  // of the same (e.g. screenshotted) QR, only one should ever flip `valid`
  // → `used`.
  //
  // Deliberately the raw SQL builder + `db.transaction`, NOT
  // `db.orm...where(...).update(...)`: found while working on BE-35 and
  // verified repeatedly against a real Postgres — with concurrent
  // unrelated background load in the same process (a BullMQ job tick
  // running at the same moment, e.g. SessionReminderProcessor), the ORM
  // lane's conditional `.update()` let 2 of 20 truly concurrent calls "win"
  // the same race instead of exactly 1, consistently reproducible. Its
  // conflict/WHERE evaluation isn't a reliably atomic single round trip,
  // same family of issue as `.where(predicate).delete()` already turning
  // out not to delete every matching row (see this gotcha in CLAUDE.md).
  // The raw `UPDATE ... WHERE ...` issued via `tx.execute(plan)` does not
  // have this problem — retested under the identical concurrent load,
  // exactly 1-of-20 every time.
  async validate(qrCodePayload: string): Promise<TicketValidationResult> {
    try {
      await this.jwtService.verifyAsync(qrCodePayload, {
        secret: ticketQrConfig.secret,
      });
    } catch {
      return { valid: false, reason: 'QR Code inválido ou adulterado' };
    }

    const plan = db.sql.public.ticket
      .update({ status: 'used', usedAt: new Date().toISOString() })
      .where((t, fns) =>
        fns.and(
          fns.eq(t.qrCodePayload, qrCodePayload),
          fns.eq(t.status, 'valid'),
        ),
      )
      .build();
    const { affectedRows } = await db.transaction((tx) => tx.execute(plan));

    if (affectedRows === 1) {
      const ticket = await db.orm.public.Ticket.where({ qrCodePayload })
        .select(...TICKET_FIELDS)
        .first();
      return { valid: true, ticket: ticket ?? undefined };
    }

    // Either it doesn't exist, or it does but the conditional update above
    // didn't match it (already "used") — one extra read only on this
    // failure path, to tell the two apart for the caller.
    const existing = await db.orm.public.Ticket.where({ qrCodePayload })
      .select(...TICKET_FIELDS)
      .first();
    if (!existing) {
      return { valid: false, reason: 'Ingresso não encontrado' };
    }
    return { valid: false, reason: 'Ingresso já utilizado', ticket: existing };
  }
}
