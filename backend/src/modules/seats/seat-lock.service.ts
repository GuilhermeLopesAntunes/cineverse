import { Inject, Injectable } from '@nestjs/common';
import type Redis from 'ioredis';
import { PARTNER_TICKETING_GATEWAY } from '../partner-integration/partner-ticketing-gateway.interface';
import type { PartnerTicketingGateway } from '../partner-integration/partner-ticketing-gateway.interface';
import { REDIS } from '../../redis/redis.module';
import { seatLockConfig } from './seat-lock.config';

export interface SeatLockResult {
  success: boolean;
  reason?: string;
}

// Runs as one atomic Redis operation — no other command can interleave
// mid-script. That's what actually makes "N seats, all or nothing" safe
// under real concurrent access (RNF-08's whole point): a plain sequence of
// SET NX calls would still race between seat #1 succeeding and seat #2
// failing, leaving a partial lock behind.
const LOCK_SCRIPT = `
for i, key in ipairs(KEYS) do
  if redis.call('EXISTS', key) == 1 then
    return 0
  end
end
for i, key in ipairs(KEYS) do
  redis.call('SET', key, ARGV[1], 'EX', ARGV[2])
end
return 1
`;

// Compare-and-delete, not a plain DEL — never release a lock this holder
// doesn't actually own. Without this check, a caller's lock could have
// already expired and been re-acquired by someone else by the time the
// release call runs; a bare DEL would then steal that other holder's lock.
const RELEASE_SCRIPT = `
if redis.call('GET', KEYS[1]) == ARGV[1] then
  return redis.call('DEL', KEYS[1])
else
  return 0
end
`;

function lockKey(sessionId: number, seatId: number): string {
  return `seat-lock:${sessionId}:${seatId}`;
}

// This is the actual RNF-08 guarantee — BE-21's MockPartnerGateway is
// explicitly NOT concurrency-safe (see its own comments) because this is
// where that safety was always meant to live. Every seat-locking entry
// point (SeatsGateway's WS `lockSeat`, the REST group-lock endpoint) goes
// through here, never through the partner gateway directly.
@Injectable()
export class SeatLockService {
  constructor(
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(PARTNER_TICKETING_GATEWAY)
    private readonly partnerGateway: PartnerTicketingGateway,
  ) {}

  async lockSeats(
    sessionId: number,
    seatIds: number[],
    userId: number,
  ): Promise<SeatLockResult> {
    const keys = seatIds.map((seatId) => lockKey(sessionId, seatId));
    const acquired = await this.redis.eval(
      LOCK_SCRIPT,
      keys.length,
      ...keys,
      String(userId),
      String(seatLockConfig.ttlSeconds),
    );

    if (acquired !== 1) {
      return {
        success: false,
        reason: 'Um ou mais assentos já estão reservados',
      };
    }

    // Keep the simulated partner/box-office view in sync too — a seat sold
    // there (never touched in our own Redis) still has to block this.
    const partnerResults = await Promise.all(
      seatIds.map((seatId) => this.partnerGateway.lockSeat(sessionId, seatId)),
    );
    const failedIndex = partnerResults.findIndex((r) => !r.success);

    if (failedIndex === -1) {
      return { success: true };
    }

    // Partial failure — roll back everything acquired so far (our own
    // Redis locks and whichever partner locks did succeed) so a failed
    // group lock never leaves a half-held selection behind.
    await Promise.all([
      this.releaseOwnedRedisLocks(sessionId, seatIds, userId),
      ...partnerResults.map((r, i) =>
        r.success
          ? this.partnerGateway.releaseSeat(sessionId, seatIds[i])
          : Promise.resolve(),
      ),
    ]);

    return {
      success: false,
      reason: partnerResults[failedIndex].reason ?? 'Assento indisponível',
    };
  }

  // Only cascades the partner release for seats this call actually held —
  // never releases the partner's lock on a seat this user didn't own here.
  // Returns the seat ids actually released, so callers only broadcast
  // `seat_released` for seats that genuinely changed state.
  async releaseSeats(
    sessionId: number,
    seatIds: number[],
    userId: number,
  ): Promise<number[]> {
    const releasedIds = await this.releaseOwnedRedisLocks(
      sessionId,
      seatIds,
      userId,
    );
    await Promise.all(
      releasedIds.map((seatId) =>
        this.partnerGateway.releaseSeat(sessionId, seatId),
      ),
    );
    return releasedIds;
  }

  // Batched existence check for SeatMapService — targeted GETs (via MGET)
  // for known seat ids, never a `KEYS` scan (Redis explicitly warns against
  // that in production: it's O(keyspace) and blocks the server).
  async getLockedSeatIds(
    sessionId: number,
    seatIds: number[],
  ): Promise<Set<number>> {
    if (seatIds.length === 0) {
      return new Set();
    }
    const keys = seatIds.map((seatId) => lockKey(sessionId, seatId));
    const values = await this.redis.mget(...keys);
    const locked = new Set<number>();
    values.forEach((value, i) => {
      if (value !== null) {
        locked.add(seatIds[i]);
      }
    });
    return locked;
  }

  // Which of these seats does *this specific user* currently hold — used by
  // order creation (BE-24) to verify the buyer actually locked every seat
  // they're trying to buy before any Order/OrderItem gets written. Not the
  // same question as getLockedSeatIds (held by *anyone*): a seat locked by
  // a different user must not let this one check out with it.
  async getSeatIdsHeldBy(
    sessionId: number,
    seatIds: number[],
    userId: number,
  ): Promise<number[]> {
    if (seatIds.length === 0) {
      return [];
    }
    const keys = seatIds.map((seatId) => lockKey(sessionId, seatId));
    const values = await this.redis.mget(...keys);
    const holderValue = String(userId);
    return seatIds.filter((_, i) => values[i] === holderValue);
  }

  // Returns the seat ids actually released (i.e. this userId really held
  // them) — callers use that to decide which partner locks to cascade.
  private async releaseOwnedRedisLocks(
    sessionId: number,
    seatIds: number[],
    userId: number,
  ): Promise<number[]> {
    const results = await Promise.all(
      seatIds.map(async (seatId) => {
        const released = await this.redis.eval(
          RELEASE_SCRIPT,
          1,
          lockKey(sessionId, seatId),
          String(userId),
        );
        return released === 1 ? seatId : null;
      }),
    );
    return results.filter((seatId): seatId is number => seatId !== null);
  }
}
