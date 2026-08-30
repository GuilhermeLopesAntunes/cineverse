import { NotFoundException } from '@nestjs/common';
import { db } from '../../prisma/db';
import { ComboItemsService } from './combo-items.service';
import { PartnersService } from './partners.service';

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        ComboItem: { select: jest.fn(), where: jest.fn() },
      },
    },
  },
}));

describe('ComboItemsService', () => {
  let service: ComboItemsService;
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
    service = new ComboItemsService(
      partnersService as unknown as PartnersService,
    );

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

    (db.orm.public.ComboItem.select as jest.Mock) = selectMock;
    (db.orm.public.ComboItem.where as jest.Mock) = whereMock;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('checks the partner exists before creating a combo', async () => {
    createMock.mockResolvedValue({
      id: 1,
      partnerId: 1,
      name: 'Pipoca + Refri',
      priceCents: 2000,
    });

    await service.create(1, { name: 'Pipoca + Refri', priceCents: 2000 });

    expect(partnersService.findOrThrow).toHaveBeenCalledWith(1);
    expect(createMock).toHaveBeenCalledWith({
      partnerId: 1,
      name: 'Pipoca + Refri',
      priceCents: 2000,
    });
  });

  it('listByPartner checks the partner exists first', async () => {
    allMock.mockResolvedValue([]);

    await service.listByPartner(1);

    expect(partnersService.findOrThrow).toHaveBeenCalledWith(1);
    expect(whereMock).toHaveBeenCalledWith({ partnerId: 1 });
  });

  it('findOrThrow throws NotFoundException when the combo does not exist', async () => {
    whereFirstMock.mockResolvedValue(undefined);

    await expect(service.findOrThrow(1)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
