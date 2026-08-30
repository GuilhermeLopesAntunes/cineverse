import { SeatLockService } from './seat-lock.service';

describe('SeatLockService', () => {
  let service: SeatLockService;
  let redis: { eval: jest.Mock; mget: jest.Mock };
  let partnerGateway: {
    lockSeat: jest.Mock;
    releaseSeat: jest.Mock;
  };

  beforeEach(() => {
    redis = { eval: jest.fn(), mget: jest.fn() };
    partnerGateway = { lockSeat: jest.fn(), releaseSeat: jest.fn() };
    service = new SeatLockService(redis as never, partnerGateway as never);
  });

  describe('lockSeats', () => {
    it('acquires the Redis lock then syncs the partner for every seat', async () => {
      redis.eval.mockResolvedValueOnce(1); // LOCK_SCRIPT: acquired
      partnerGateway.lockSeat.mockResolvedValue({ success: true });

      const result = await service.lockSeats(1, [10, 11], 42);

      expect(result).toEqual({ success: true });
      expect(redis.eval).toHaveBeenCalledWith(
        expect.any(String),
        2,
        'seat-lock:1:10',
        'seat-lock:1:11',
        '42',
        '300',
      );
      expect(partnerGateway.lockSeat).toHaveBeenCalledWith(1, 10);
      expect(partnerGateway.lockSeat).toHaveBeenCalledWith(1, 11);
    });

    it('fails fast without touching the partner when the Redis script reports a conflict', async () => {
      redis.eval.mockResolvedValueOnce(0); // LOCK_SCRIPT: one of the keys already existed

      const result = await service.lockSeats(1, [10], 42);

      expect(result.success).toBe(false);
      expect(result.reason).toMatch(/reservados/);
      expect(partnerGateway.lockSeat).not.toHaveBeenCalled();
    });

    it('rolls back every acquired lock (Redis and partner) when one seat fails on the partner side', async () => {
      redis.eval.mockResolvedValueOnce(1); // LOCK_SCRIPT: acquired both
      partnerGateway.lockSeat
        .mockResolvedValueOnce({ success: true }) // seat 10 ok on the partner
        .mockResolvedValueOnce({
          success: false,
          reason: 'Assento já vendido',
        }); // seat 11 fails
      redis.eval.mockResolvedValue(1); // RELEASE_SCRIPT calls during rollback

      const result = await service.lockSeats(1, [10, 11], 42);

      expect(result).toEqual({ success: false, reason: 'Assento já vendido' });
      // Rollback: release our own Redis lock for both seats...
      expect(redis.eval).toHaveBeenCalledWith(
        expect.any(String),
        1,
        'seat-lock:1:10',
        '42',
      );
      expect(redis.eval).toHaveBeenCalledWith(
        expect.any(String),
        1,
        'seat-lock:1:11',
        '42',
      );
      // ...and release the partner lock only for the seat that DID succeed there.
      expect(partnerGateway.releaseSeat).toHaveBeenCalledWith(1, 10);
      expect(partnerGateway.releaseSeat).not.toHaveBeenCalledWith(1, 11);
    });
  });

  describe('releaseSeats', () => {
    it('cascades the partner release only for seats this caller actually held', async () => {
      redis.eval
        .mockResolvedValueOnce(1) // owned seat 10 -> released
        .mockResolvedValueOnce(0); // seat 11 not owned by this user -> no-op

      const released = await service.releaseSeats(1, [10, 11], 42);

      expect(released).toEqual([10]);
      expect(partnerGateway.releaseSeat).toHaveBeenCalledWith(1, 10);
      expect(partnerGateway.releaseSeat).not.toHaveBeenCalledWith(1, 11);
    });
  });

  describe('getSeatIdsHeldBy', () => {
    it('returns an empty array without calling Redis for an empty seat list', async () => {
      const result = await service.getSeatIdsHeldBy(1, [], 42);

      expect(result).toEqual([]);
      expect(redis.mget).not.toHaveBeenCalled();
    });

    it('only returns seats actually held by the given user, not by anyone else', async () => {
      redis.mget.mockResolvedValue(['42', '99', null]);

      const result = await service.getSeatIdsHeldBy(1, [10, 11, 12], 42);

      expect(redis.mget).toHaveBeenCalledWith(
        'seat-lock:1:10',
        'seat-lock:1:11',
        'seat-lock:1:12',
      );
      expect(result).toEqual([10]);
    });
  });

  describe('getLockedSeatIds', () => {
    it('returns an empty set without calling Redis for an empty seat list', async () => {
      const result = await service.getLockedSeatIds(1, []);

      expect(result).toEqual(new Set());
      expect(redis.mget).not.toHaveBeenCalled();
    });

    it('maps mget results back to the held seat ids', async () => {
      redis.mget.mockResolvedValue(['42', null, '7']);

      const result = await service.getLockedSeatIds(1, [10, 11, 12]);

      expect(redis.mget).toHaveBeenCalledWith(
        'seat-lock:1:10',
        'seat-lock:1:11',
        'seat-lock:1:12',
      );
      expect(result).toEqual(new Set([10, 12]));
    });
  });
});
