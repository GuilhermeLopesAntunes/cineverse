import { ConflictException, NotFoundException } from '@nestjs/common';
import { db } from '../../prisma/db';
import { SeatsService } from './seats.service';

interface FakeTx {
  orm: {
    public: {
      Seat: { select: jest.Mock };
    };
  };
}

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        Room: { where: jest.fn() },
        Seat: { where: jest.fn() },
      },
    },
    transaction: jest.fn(),
  },
}));

describe('SeatsService', () => {
  let service: SeatsService;
  let roomFirstMock: jest.Mock;
  let roomWhereMock: jest.Mock;
  let seatFirstMock: jest.Mock;
  let seatOrderByMock: jest.Mock;
  let seatSelectMock: jest.Mock;
  let seatWhereMock: jest.Mock;
  let transactionMock: jest.Mock;
  let createMock: jest.Mock;

  beforeEach(() => {
    service = new SeatsService();

    roomFirstMock = jest.fn().mockResolvedValue({ id: 1 });
    roomWhereMock = jest.fn().mockReturnValue({ first: roomFirstMock });

    seatFirstMock = jest.fn();
    seatOrderByMock = jest
      .fn()
      .mockReturnValue({ all: jest.fn().mockResolvedValue([]) });
    seatSelectMock = jest
      .fn()
      .mockReturnValue({ first: seatFirstMock, orderBy: seatOrderByMock });
    seatWhereMock = jest.fn().mockReturnValue({ select: seatSelectMock });

    createMock = jest.fn();
    transactionMock = jest
      .fn()
      .mockImplementation(
        async (callback: (tx: FakeTx) => Promise<unknown>) => {
          const tx: FakeTx = {
            orm: {
              public: {
                Seat: {
                  select: jest.fn().mockReturnValue({ create: createMock }),
                },
              },
            },
          };
          return callback(tx);
        },
      );

    (db.orm.public.Room.where as jest.Mock) = roomWhereMock;
    (db.orm.public.Seat.where as jest.Mock) = seatWhereMock;
    (db.transaction as unknown as jest.Mock) = transactionMock;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('checks the room exists before creating seats', async () => {
    createMock
      .mockResolvedValueOnce({ id: 1, roomId: 1, code: 'A1' })
      .mockResolvedValueOnce({ id: 2, roomId: 1, code: 'A2' });

    const result = await service.createMany(1, { codes: ['A1', 'A2'] });

    expect(roomWhereMock).toHaveBeenCalledWith({ id: 1 });
    expect(createMock).toHaveBeenCalledTimes(2);
    expect(result).toHaveLength(2);
  });

  it('throws NotFoundException without starting a transaction when the room does not exist', async () => {
    roomFirstMock.mockResolvedValue(undefined);

    await expect(
      service.createMany(999, { codes: ['A1'] }),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(transactionMock).not.toHaveBeenCalled();
  });

  it('translates a duplicate seat code into a ConflictException (whole batch rolled back)', async () => {
    createMock.mockRejectedValue({ sqlState: '23505' });

    await expect(
      service.createMany(1, { codes: ['A1'] }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('listByRoom checks the room exists first', async () => {
    await service.listByRoom(1);

    expect(roomWhereMock).toHaveBeenCalledWith({ id: 1 });
    expect(seatWhereMock).toHaveBeenCalledWith({ roomId: 1 });
  });

  it('listByRoom throws NotFoundException when the room does not exist', async () => {
    roomFirstMock.mockResolvedValue(undefined);

    await expect(service.listByRoom(999)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
