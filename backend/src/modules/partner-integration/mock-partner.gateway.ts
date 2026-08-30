import { Injectable, NotFoundException } from '@nestjs/common';
import { isUniqueViolation } from '../../common/prisma/is-unique-violation';
import { db } from '../../prisma/db';
import {
  PartnerConfirmSaleResult,
  PartnerLockResult,
  PartnerSeatMapEntry,
  PartnerSeatStatus,
  PartnerTicketingGateway,
} from './partner-ticketing-gateway.interface';

interface StateRow {
  id: number;
  status: string;
  soldOrderId: number | null;
}

// Simulates the partner's own ticketing system (no real partner available
// for the MVP — ARQUITETURA_BACKEND.md § 7). This is a state machine over
// `PartnerSeatState`, one row per (session, seat), created lazily on first
// touch (no row = "available").
//
// Not concurrency-hardened on purpose: the actual "zero duplicidade de
// venda" guarantee (RNF-08) is this app's own Redis lock (BE-23), not this
// mock. A real partner's ERP has its own internal consistency that we don't
// control either way — what this class needs to get right is the state
// machine's behavior across sequential reserve → sell → release calls, not
// arbitrate races a real gateway wouldn't let us referee anyway.
@Injectable()
export class MockPartnerGateway implements PartnerTicketingGateway {
  async getSeatMap(sessionId: number): Promise<PartnerSeatMapEntry[]> {
    const session = await this.findSessionOrThrow(sessionId);
    const seats = await db.orm.public.Seat.where({ roomId: session.roomId })
      .select('id')
      .all();
    const states = await db.orm.public.PartnerSeatState.where({ sessionId })
      .select('seatId', 'status')
      .all();
    const statusBySeatId = new Map(
      states.map((s) => [s.seatId, s.status as PartnerSeatStatus]),
    );

    return seats.map((seat) => ({
      seatId: seat.id,
      status: statusBySeatId.get(seat.id) ?? 'available',
    }));
  }

  async lockSeat(
    sessionId: number,
    seatId: number,
  ): Promise<PartnerLockResult> {
    await this.assertSeatInSession(sessionId, seatId);
    const state = await this.ensureStateRow(sessionId, seatId);

    if (state.status !== 'available') {
      return { success: false, reason: this.unavailableReason(state.status) };
    }

    await db.orm.public.PartnerSeatState.where({ id: state.id }).update({
      status: 'locked',
    });
    return { success: true };
  }

  async confirmSale(
    sessionId: number,
    seatId: number,
    orderId: number,
  ): Promise<PartnerConfirmSaleResult> {
    await this.assertSeatInSession(sessionId, seatId);
    const state = await this.ensureStateRow(sessionId, seatId);

    if (state.status === 'sold') {
      // Same order confirming again (e.g. a retried payment webhook,
      // BE-30) is a no-op, not a conflict — anything else means someone
      // else already bought this seat.
      if (state.soldOrderId === orderId) {
        return { success: true };
      }
      return { success: false, reason: 'Assento já vendido para outro pedido' };
    }

    await db.orm.public.PartnerSeatState.where({ id: state.id }).update({
      status: 'sold',
      soldOrderId: orderId,
    });
    return { success: true };
  }

  async releaseSeat(sessionId: number, seatId: number): Promise<void> {
    await this.assertSeatInSession(sessionId, seatId);
    const state = await this.ensureStateRow(sessionId, seatId);

    // A confirmed sale needs a refund/cancellation flow, not a release —
    // out of scope here, so this is a deliberate no-op rather than
    // silently undoing a sale.
    if (state.status === 'sold') {
      return;
    }

    await db.orm.public.PartnerSeatState.where({ id: state.id }).update({
      status: 'available',
      soldOrderId: null,
    });
  }

  private unavailableReason(status: string): string {
    return status === 'sold'
      ? 'Assento já vendido'
      : 'Assento já reservado por outro cliente';
  }

  private async ensureStateRow(
    sessionId: number,
    seatId: number,
  ): Promise<StateRow> {
    const existing = await db.orm.public.PartnerSeatState.where({
      sessionId,
      seatId,
    })
      .select('id', 'status', 'soldOrderId')
      .first();
    if (existing) {
      return existing;
    }

    try {
      return await db.orm.public.PartnerSeatState.select(
        'id',
        'status',
        'soldOrderId',
      ).create({ sessionId, seatId, status: 'available' });
    } catch (err) {
      // Another request created the row between our read and our create —
      // read it back instead of failing; it's "available" either way.
      if (isUniqueViolation(err)) {
        const row = await db.orm.public.PartnerSeatState.where({
          sessionId,
          seatId,
        })
          .select('id', 'status', 'soldOrderId')
          .first();
        if (row) {
          return row;
        }
      }
      throw err;
    }
  }

  private async findSessionOrThrow(sessionId: number) {
    const session = await db.orm.public.Session.where({
      id: sessionId,
    }).first();
    if (!session) {
      throw new NotFoundException(`Sessão ${sessionId} não encontrada`);
    }
    return session;
  }

  private async assertSeatInSession(
    sessionId: number,
    seatId: number,
  ): Promise<void> {
    const session = await this.findSessionOrThrow(sessionId);
    const seat = await db.orm.public.Seat.where({
      id: seatId,
      roomId: session.roomId,
    }).first();
    if (!seat) {
      throw new NotFoundException(
        `Assento ${seatId} não pertence à sessão ${sessionId}`,
      );
    }
  }
}
