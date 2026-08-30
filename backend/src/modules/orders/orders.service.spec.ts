import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { db } from '../../prisma/db';
import { OrdersService } from './orders.service';

interface Chain {
  where: jest.Mock;
  select: jest.Mock;
  orderBy: jest.Mock;
  offset: jest.Mock;
  limit: jest.Mock;
  first: jest.Mock;
  all: jest.Mock;
  aggregate: jest.Mock;
}

function makeChain(): Chain {
  const chain = {} as Chain;
  chain.where = jest.fn().mockReturnValue(chain);
  chain.select = jest.fn().mockReturnValue(chain);
  chain.orderBy = jest.fn().mockReturnValue(chain);
  chain.offset = jest.fn().mockReturnValue(chain);
  chain.limit = jest.fn().mockReturnValue(chain);
  chain.first = jest.fn();
  chain.all = jest.fn().mockResolvedValue([]);
  chain.aggregate = jest.fn().mockResolvedValue({ total: 0 });
  return chain;
}

interface FakeTx {
  orm: {
    public: {
      Order: { select: jest.Mock };
      OrderItem: { create: jest.Mock };
    };
  };
}

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        Session: {},
        Order: {},
        OrderItem: {},
        Room: {},
        ComboItem: {},
      },
    },
    transaction: jest.fn(),
  },
}));

describe('OrdersService', () => {
  let service: OrdersService;
  let seatLockService: { getSeatIdsHeldBy: jest.Mock };
  let sessionChain: Chain;
  let orderChain: Chain;
  let orderItemChain: Chain;
  let orderItemWhereMock: jest.Mock;
  let roomChain: Chain;
  let comboItemChain: Chain;
  let transactionMock: jest.Mock;
  let orderCreateMock: jest.Mock;
  let orderItemCreateMock: jest.Mock;

  const sampleSession = { id: 1, roomId: 5, priceCents: 2500 };
  const sampleRoom = { id: 5, partnerId: 50 };
  const sampleOrder = {
    id: 10,
    userId: 1,
    sessionId: 1,
    status: 'pending',
    totalAmountCents: 2500,
    createdAt: 'now',
  };

  beforeEach(() => {
    seatLockService = { getSeatIdsHeldBy: jest.fn().mockResolvedValue([100]) };
    service = new OrdersService(seatLockService as never);

    sessionChain = makeChain();
    sessionChain.first.mockResolvedValue(sampleSession);
    orderChain = makeChain();
    orderChain.first.mockResolvedValue(sampleOrder);
    orderItemChain = makeChain();
    roomChain = makeChain();
    roomChain.first.mockResolvedValue(sampleRoom);
    comboItemChain = makeChain();

    (db.orm.public.Session as unknown as { where: jest.Mock }).where = jest
      .fn()
      .mockReturnValue(sessionChain);
    (db.orm.public.Order as unknown as { where: jest.Mock }).where = jest
      .fn()
      .mockReturnValue(orderChain);
    orderItemWhereMock = jest.fn().mockReturnValue(orderItemChain);
    (db.orm.public.OrderItem as unknown as { where: jest.Mock }).where =
      orderItemWhereMock;
    (db.orm.public.Room as unknown as { where: jest.Mock }).where = jest
      .fn()
      .mockReturnValue(roomChain);
    (db.orm.public.ComboItem as unknown as { where: jest.Mock }).where = jest
      .fn()
      .mockReturnValue(comboItemChain);

    orderCreateMock = jest.fn().mockResolvedValue(sampleOrder);
    orderItemCreateMock = jest.fn().mockResolvedValue(undefined);
    transactionMock = jest
      .fn()
      .mockImplementation(
        async (callback: (tx: FakeTx) => Promise<unknown>) => {
          const tx: FakeTx = {
            orm: {
              public: {
                Order: {
                  select: jest
                    .fn()
                    .mockReturnValue({ create: orderCreateMock }),
                },
                OrderItem: { create: orderItemCreateMock },
              },
            },
          };
          return callback(tx);
        },
      );
    (db.transaction as unknown as jest.Mock) = transactionMock;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('create', () => {
    it('throws NotFoundException when the session does not exist', async () => {
      sessionChain.first.mockResolvedValue(undefined);

      await expect(
        service.create(1, { sessionId: 999, items: [{ seatId: 100 }] }),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(transactionMock).not.toHaveBeenCalled();
    });

    it('throws ConflictException when a seat is not held by this user', async () => {
      seatLockService.getSeatIdsHeldBy.mockResolvedValue([100]); // 101 missing

      await expect(
        service.create(1, {
          sessionId: 1,
          items: [{ seatId: 100 }, { seatId: 101 }],
        }),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(transactionMock).not.toHaveBeenCalled();
    });

    it('creates an order with one OrderItem per seat and the correct total', async () => {
      seatLockService.getSeatIdsHeldBy.mockResolvedValue([100, 101]);

      const result = await service.create(1, {
        sessionId: 1,
        items: [{ seatId: 100 }, { seatId: 101 }],
      });

      expect(orderCreateMock).toHaveBeenCalledWith({
        userId: 1,
        sessionId: 1,
        status: 'pending',
        totalAmountCents: 5000, // 2500 * 2 seats, no combos
      });
      expect(orderItemCreateMock).toHaveBeenCalledTimes(2);
      expect(orderItemCreateMock).toHaveBeenCalledWith({
        orderId: sampleOrder.id,
        seatId: 100,
        comboItemId: null,
      });
      expect(orderItemCreateMock).toHaveBeenCalledWith({
        orderId: sampleOrder.id,
        seatId: 101,
        comboItemId: null,
      });
      expect(result).toEqual({
        ...sampleOrder,
        items: [
          { seatId: 100, comboItemId: null },
          { seatId: 101, comboItemId: null },
        ],
      });
    });

    it('adds the combo price to the total and links it on the OrderItem', async () => {
      seatLockService.getSeatIdsHeldBy.mockResolvedValue([100]);
      comboItemChain.all.mockResolvedValue([
        { id: 7, partnerId: 50, priceCents: 800 },
      ]);

      const result = await service.create(1, {
        sessionId: 1,
        items: [{ seatId: 100, comboItemId: 7 }],
      });

      expect(orderCreateMock).toHaveBeenCalledWith({
        userId: 1,
        sessionId: 1,
        status: 'pending',
        totalAmountCents: 3300, // 2500 seat + 800 combo
      });
      expect(orderItemCreateMock).toHaveBeenCalledWith({
        orderId: sampleOrder.id,
        seatId: 100,
        comboItemId: 7,
      });
      expect(result.items).toEqual([{ seatId: 100, comboItemId: 7 }]);
    });

    it('throws NotFoundException when a combo id does not exist', async () => {
      comboItemChain.all.mockResolvedValue([]);

      await expect(
        service.create(1, {
          sessionId: 1,
          items: [{ seatId: 100, comboItemId: 999 }],
        }),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(transactionMock).not.toHaveBeenCalled();
    });

    it('throws BadRequestException when a combo belongs to a different partner', async () => {
      comboItemChain.all.mockResolvedValue([
        { id: 7, partnerId: 999, priceCents: 800 },
      ]);

      await expect(
        service.create(1, {
          sessionId: 1,
          items: [{ seatId: 100, comboItemId: 7 }],
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(transactionMock).not.toHaveBeenCalled();
    });
  });

  describe('findOne', () => {
    it('throws NotFoundException when the order does not exist', async () => {
      orderChain.first.mockResolvedValue(undefined);

      await expect(service.findOne(999, 1)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('throws ForbiddenException when the order belongs to someone else', async () => {
      await expect(service.findOne(10, 999)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it('returns the order with its items', async () => {
      orderItemChain.all.mockResolvedValue([
        { seatId: 100, comboItemId: null },
        { seatId: 101, comboItemId: 7 },
      ]);

      const result = await service.findOne(10, 1);

      expect(result).toEqual({
        ...sampleOrder,
        items: [
          { seatId: 100, comboItemId: null },
          { seatId: 101, comboItemId: 7 },
        ],
      });
    });
  });

  describe('list', () => {
    it('returns paginated orders with their items grouped correctly', async () => {
      orderChain.all.mockResolvedValue([sampleOrder]);
      orderChain.aggregate.mockResolvedValue({ total: 1 });
      orderItemChain.all.mockResolvedValue([
        { orderId: 10, seatId: 100, comboItemId: null },
      ]);

      const result = await service.list(1, 1, 20);

      expect(result).toEqual({
        items: [
          { ...sampleOrder, items: [{ seatId: 100, comboItemId: null }] },
        ],
        page: 1,
        pageSize: 20,
        total: 1,
        totalPages: 1,
      });
    });

    it('skips the OrderItem query entirely when there are no orders', async () => {
      orderChain.all.mockResolvedValue([]);
      orderChain.aggregate.mockResolvedValue({ total: 0 });

      const result = await service.list(1, 1, 20);

      expect(result.items).toEqual([]);
      expect(orderItemWhereMock).not.toHaveBeenCalled();
    });
  });
});
