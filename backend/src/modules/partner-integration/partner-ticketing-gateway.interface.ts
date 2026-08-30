// Abstraction over the cinema partner's own ticketing/box-office system
// (ARQUITETURA_BACKEND.md § 7, RNF-02/RNF-10) — the point is that BE-22
// (real-time seat map), BE-24/25 (checkout) and BE-30 (payment webhook)
// depend on this interface, never on a concrete gateway, so a second real
// partner can be plugged in later without touching them. BE-21's
// `MockPartnerGateway` is the only implementation for now.
//
// This is deliberately NOT this app's own reservation lock — that one is
// `SeatLock` in Redis (BE-23), which is what actually guarantees RNF-08
// (zero duplicidade de venda). This interface exists so a seat sold at the
// physical box office (or another sales channel the partner also serves)
// is reflected here too — the two locks protect against different sources
// of a double sale.

export type PartnerSeatStatus = 'available' | 'locked' | 'sold';

export interface PartnerSeatMapEntry {
  seatId: number;
  status: PartnerSeatStatus;
}

export interface PartnerLockResult {
  success: boolean;
  // Set only when success is false — e.g. the seat was just sold at the
  // physical box office. Never thrown as an exception: a lock that fails
  // because someone else got there first is an expected, routine outcome,
  // not an error condition.
  reason?: string;
}

export interface PartnerConfirmSaleResult {
  success: boolean;
  reason?: string;
}

export interface PartnerTicketingGateway {
  // Current status of every seat in the session, as seen by the partner's
  // own system. Combined with this app's own Redis locks at a higher layer
  // (BE-22) — this call alone doesn't know about locks this app is holding
  // that the partner hasn't been told about yet.
  getSeatMap(sessionId: number): Promise<PartnerSeatMapEntry[]>;

  // Places a temporary hold with the partner, one seat at a time — not a
  // batch operation, since a real partner's ERP might not support batching
  // at all, and this app's own atomicity guarantee (RNF-08) is Redis's job
  // (BE-23), not this interface's.
  lockSeat(sessionId: number, seatId: number): Promise<PartnerLockResult>;

  // Idempotent by contract: a payment webhook can be delivered more than
  // once (BE-30), and confirming an already-confirmed sale must be a safe
  // no-op, not a duplicate charge or a thrown error.
  confirmSale(
    sessionId: number,
    seatId: number,
    orderId: number,
  ): Promise<PartnerConfirmSaleResult>;

  // Releases a previously locked seat back to available — checkout
  // timeout or cancellation before payment confirms.
  releaseSeat(sessionId: number, seatId: number): Promise<void>;
}

export const PARTNER_TICKETING_GATEWAY = Symbol('PARTNER_TICKETING_GATEWAY');
