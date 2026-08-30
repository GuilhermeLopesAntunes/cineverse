import { NotFoundException } from '@nestjs/common';
import { db } from '../../prisma/db';
import { MockPartnerGateway } from './mock-partner.gateway';

interface Chain {
  where: jest.Mock;
  select: jest.Mock;
  first: jest.Mock;
  all: jest.Mock;
  update: jest.Mock;
  create: jest.Mock;
}

function makeChain(): Chain {
  const chain = {} as Chain;
  chain.where = jest.fn().mockReturnValue(chain);
  chain.select = jest.fn().mockReturnValue(chain);
  chain.first = jest.fn();
  chain.all = jest.fn().mockResolvedValue([]);
  chain.update = jest.fn().mockResolvedValue(undefined);
  chain.create = jest.fn();
  return chain;
}

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        Session: {},
        Seat: {},
        PartnerSeatState: {},
      },
    },
  },
}));

describe('MockPartnerGateway', () => {
  let gateway: MockPartnerGateway;
  let sessionChain: Chain;
  let seatChain: Chain;
  let stateChain: Chain;
  let stateCreateMock: jest.Mock;

  const sampleSession = { id: 1, roomId: 10 };
  const sampleSeat = { id: 100, roomId: 10 };

  beforeEach(() => {
    gateway = new MockPartnerGateway();

    sessionChain = makeChain();
    sessionChain.first.mockResolvedValue(sampleSession);

    seatChain = makeChain();
    seatChain.first.mockResolvedValue(sampleSeat);

    stateChain = makeChain();
    stateChain.first.mockResolvedValue(undefined); // no row yet, by default

    stateCreateMock = jest
      .fn()
      .mockResolvedValue({ id: 1, status: 'available', soldOrderId: null });

    (db.orm.public.Session as unknown as { where: jest.Mock }).where = jest
      .fn()
      .mockReturnValue(sessionChain);
    (db.orm.public.Seat as unknown as { where: jest.Mock }).where = jest
      .fn()
      .mockReturnValue(seatChain);
    (db.orm.public.PartnerSeatState as unknown as { where: jest.Mock }).where =
      jest.fn().mockReturnValue(stateChain);
    (
      db.orm.public.PartnerSeatState as unknown as { select: jest.Mock }
    ).select = jest.fn().mockReturnValue({ create: stateCreateMock });
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getSeatMap', () => {
    it('throws NotFoundException when the session does not exist', async () => {
      sessionChain.first.mockResolvedValue(undefined);

      await expect(gateway.getSeatMap(999)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('defaults seats with no state row to "available"', async () => {
      seatChain.all.mockResolvedValue([{ id: 100 }, { id: 101 }]);
      stateChain.all.mockResolvedValue([{ seatId: 100, status: 'sold' }]);

      const result = await gateway.getSeatMap(1);

      expect(result).toEqual([
        { seatId: 100, status: 'sold' },
        { seatId: 101, status: 'available' },
      ]);
    });
  });

  describe('lockSeat', () => {
    it('locks an available seat', async () => {
      stateChain.first.mockResolvedValue(undefined);
      stateCreateMock.mockResolvedValue({
        id: 5,
        status: 'available',
        soldOrderId: null,
      });

      const result = await gateway.lockSeat(1, 100);

      expect(result).toEqual({ success: true });
      expect(stateChain.update).toHaveBeenCalledWith({ status: 'locked' });
    });

    it('fails to lock a seat that is already locked', async () => {
      stateChain.first.mockResolvedValue({
        id: 5,
        status: 'locked',
        soldOrderId: null,
      });

      const result = await gateway.lockSeat(1, 100);

      expect(result.success).toBe(false);
      expect(result.reason).toMatch(/reservado/);
      expect(stateChain.update).not.toHaveBeenCalled();
    });

    it('fails to lock a seat that is already sold', async () => {
      stateChain.first.mockResolvedValue({
        id: 5,
        status: 'sold',
        soldOrderId: 42,
      });

      const result = await gateway.lockSeat(1, 100);

      expect(result.success).toBe(false);
      expect(result.reason).toMatch(/vendido/);
    });

    it('throws NotFoundException when the seat does not belong to the session', async () => {
      seatChain.first.mockResolvedValue(undefined);

      await expect(gateway.lockSeat(1, 999)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('recovers from a unique-violation race by reading the row back', async () => {
      stateChain.first
        .mockResolvedValueOnce(undefined) // ensureStateRow's initial read
        .mockResolvedValueOnce({
          id: 5,
          status: 'available',
          soldOrderId: null,
        }); // read-back after the race
      stateCreateMock.mockRejectedValue({ sqlState: '23505' });

      const result = await gateway.lockSeat(1, 100);

      expect(result).toEqual({ success: true });
    });
  });

  describe('confirmSale', () => {
    it('sells an available seat', async () => {
      stateChain.first.mockResolvedValue(undefined);
      stateCreateMock.mockResolvedValue({
        id: 5,
        status: 'available',
        soldOrderId: null,
      });

      const result = await gateway.confirmSale(1, 100, 42);

      expect(result).toEqual({ success: true });
      expect(stateChain.update).toHaveBeenCalledWith({
        status: 'sold',
        soldOrderId: 42,
      });
    });

    it('sells a locked seat', async () => {
      stateChain.first.mockResolvedValue({
        id: 5,
        status: 'locked',
        soldOrderId: null,
      });

      const result = await gateway.confirmSale(1, 100, 42);

      expect(result).toEqual({ success: true });
    });

    it('is idempotent when the same order re-confirms an already-sold seat', async () => {
      stateChain.first.mockResolvedValue({
        id: 5,
        status: 'sold',
        soldOrderId: 42,
      });

      const result = await gateway.confirmSale(1, 100, 42);

      expect(result).toEqual({ success: true });
      expect(stateChain.update).not.toHaveBeenCalled();
    });

    it('rejects a different order trying to buy an already-sold seat', async () => {
      stateChain.first.mockResolvedValue({
        id: 5,
        status: 'sold',
        soldOrderId: 42,
      });

      const result = await gateway.confirmSale(1, 100, 99);

      expect(result.success).toBe(false);
    });
  });

  describe('releaseSeat', () => {
    it('releases a locked seat back to available', async () => {
      stateChain.first.mockResolvedValue({
        id: 5,
        status: 'locked',
        soldOrderId: null,
      });

      await gateway.releaseSeat(1, 100);

      expect(stateChain.update).toHaveBeenCalledWith({
        status: 'available',
        soldOrderId: null,
      });
    });

    it('does not release a sold seat', async () => {
      stateChain.first.mockResolvedValue({
        id: 5,
        status: 'sold',
        soldOrderId: 42,
      });

      await gateway.releaseSeat(1, 100);

      expect(stateChain.update).not.toHaveBeenCalled();
    });
  });
});
