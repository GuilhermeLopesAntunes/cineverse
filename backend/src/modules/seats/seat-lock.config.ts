export interface SeatLockConfig {
  ttlSeconds: number;
}

export const seatLockConfig: SeatLockConfig = {
  // How long an atomic seat hold survives before Redis expires it and the
  // seat becomes lockable again — ARQUITETURA_BACKEND.md § 5's "falha/timeout
  // de pagamento → lock expira pelo TTL". Default: 5 minutes to complete
  // checkout.
  ttlSeconds: Number(process.env.SEAT_LOCK_TTL_SECONDS ?? 300),
};
