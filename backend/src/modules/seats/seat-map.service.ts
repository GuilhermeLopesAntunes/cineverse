import { Inject, Injectable } from '@nestjs/common';
import { db } from '../../prisma/db';
import { PARTNER_TICKETING_GATEWAY } from '../partner-integration/partner-ticketing-gateway.interface';
import type { PartnerConfirmSaleResult } from '../partner-integration/partner-ticketing-gateway.interface';
import type { PartnerTicketingGateway } from '../partner-integration/partner-ticketing-gateway.interface';
import { SeatLockService } from './seat-lock.service';

export interface SeatMapEntry {
  seatId: number;
  code: string;
  status: 'available' | 'locked' | 'sold';
}

// Combined read model for RF-10/BE-22's real-time map: the partner's own
// status (BE-20/21) overlaid with this app's own Redis holds (BE-23) —
// ARQUITETURA_BACKEND.md § 5's "combina locks ativos (Redis) + status do
// parceiro". In the normal path these already agree (SeatLockService syncs
// the partner right after acquiring its own lock), but this overlay is what
// keeps the map honest even if that sync were ever momentarily behind.
// Locking/releasing itself lives in SeatLockService now, not here — this
// class is read-only plus the one write BE-22 introduced before BE-23
// existed (the box-office sale simulation).
@Injectable()
export class SeatMapService {
  constructor(
    @Inject(PARTNER_TICKETING_GATEWAY)
    private readonly partnerGateway: PartnerTicketingGateway,
    private readonly seatLockService: SeatLockService,
  ) {}

  async getMap(sessionId: number): Promise<SeatMapEntry[]> {
    const statuses = await this.partnerGateway.getSeatMap(sessionId);
    const seatIds = statuses.map((s) => s.seatId);

    const seats: { id: number; code: string }[] =
      seatIds.length === 0
        ? []
        : await db.orm.public.Seat.where((s) => s.id.in(seatIds))
            .select('id', 'code')
            .all();
    const redisLocked = await this.seatLockService.getLockedSeatIds(
      sessionId,
      seatIds,
    );
    const codeById = new Map(seats.map((s) => [s.id, s.code]));

    return statuses.map((s) => ({
      seatId: s.seatId,
      code: codeById.get(s.seatId) ?? '',
      status:
        s.status === 'available' && redisLocked.has(s.seatId)
          ? 'locked'
          : s.status,
    }));
  }

  // Simulates a sale made outside the app (the physical box office) —
  // there's no real checkout flow yet to drive this the normal way
  // (BE-24/25), so this is the only current caller of confirmSale.
  boxOfficeSale(
    sessionId: number,
    seatId: number,
    orderId: number,
  ): Promise<PartnerConfirmSaleResult> {
    return this.partnerGateway.confirmSale(sessionId, seatId, orderId);
  }
}
