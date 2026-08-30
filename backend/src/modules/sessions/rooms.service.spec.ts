import { ConflictException, NotFoundException } from '@nestjs/common';
import { db } from '../../prisma/db';
import { PartnersService } from './partners.service';
import { RoomsService } from './rooms.service';

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        Room: { select: jest.fn(), where: jest.fn() },
      },
    },
  },
}));

describe('RoomsService', () => {
  let service: RoomsService;
  let partnersService: { findOrThrow: jest.Mock };
  let createMock: jest.Mock;
  let selectMock: jest.Mock;
  let allMock: jest.Mock;
  let orderByMock: jest.Mock;
  let whereSelectMock: jest.Mock;
  let whereOrderByMock: jest.Mock;
  let whereFirstMock: jest.Mock;
  let whereMock: jest.Mock;

  beforeEach(() => {
    partnersService = { findOrThrow: jest.fn().mockResolvedValue({ id: 1 }) };
    service = new RoomsService(partnersService as unknown as PartnersService);

    createMock = jest.fn();
    allMock = jest.fn();
    orderByMock = jest.fn().mockReturnValue({ all: allMock });
    selectMock = jest
      .fn()
      .mockReturnValue({ create: createMock, orderBy: orderByMock });

    whereFirstMock = jest.fn();
    whereOrderByMock = jest.fn().mockReturnValue({ all: allMock });
    whereSelectMock = jest.fn().mockReturnValue({
      first: whereFirstMock,
      orderBy: whereOrderByMock,
    });
    whereMock = jest.fn().mockReturnValue({ select: whereSelectMock });

    (db.orm.public.Room.select as jest.Mock) = selectMock;
    (db.orm.public.Room.where as jest.Mock) = whereMock;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('checks the partner exists before creating a room', async () => {
    createMock.mockResolvedValue({ id: 1, partnerId: 1, name: 'Sala 1' });

    await service.create(1, { name: 'Sala 1' });

    expect(partnersService.findOrThrow).toHaveBeenCalledWith(1);
    expect(createMock).toHaveBeenCalledWith({ partnerId: 1, name: 'Sala 1' });
  });

  it('translates a duplicate room name for the same partner into a ConflictException', async () => {
    createMock.mockRejectedValue({ sqlState: '23505' });

    await expect(service.create(1, { name: 'Sala 1' })).rejects.toBeInstanceOf(
      ConflictException,
    );
  });

  it('rethrows errors unrelated to a unique-constraint violation', async () => {
    const dbError = new Error('connection lost');
    createMock.mockRejectedValue(dbError);

    await expect(service.create(1, { name: 'Sala 1' })).rejects.toBe(dbError);
  });

  it('listByPartner checks the partner exists first', async () => {
    allMock.mockResolvedValue([]);

    await service.listByPartner(1);

    expect(partnersService.findOrThrow).toHaveBeenCalledWith(1);
    expect(whereMock).toHaveBeenCalledWith({ partnerId: 1 });
  });

  it('findOrThrow throws NotFoundException when the room does not exist', async () => {
    whereFirstMock.mockResolvedValue(undefined);

    await expect(service.findOrThrow(1)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
