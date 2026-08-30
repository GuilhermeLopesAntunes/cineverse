import { NotFoundException } from '@nestjs/common';
import { db } from '../../prisma/db';
import { PartnersService } from './partners.service';

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        CinemaPartner: { select: jest.fn(), where: jest.fn() },
      },
    },
  },
}));

function partner(overrides: Record<string, unknown> = {}) {
  return {
    id: 1,
    name: 'Cinema X',
    apiConfig: null,
    latitude: -22.9711,
    longitude: -43.1822,
    createdAt: 'now',
    ...overrides,
  };
}

describe('PartnersService', () => {
  let service: PartnersService;
  let createMock: jest.Mock;
  let allMock: jest.Mock;
  let orderByMock: jest.Mock;
  let selectMock: jest.Mock;
  let firstMock: jest.Mock;
  let whereSelectMock: jest.Mock;
  let whereMock: jest.Mock;

  beforeEach(() => {
    service = new PartnersService();

    createMock = jest.fn();
    allMock = jest.fn();
    orderByMock = jest.fn().mockReturnValue({ all: allMock });
    selectMock = jest
      .fn()
      .mockReturnValue({ create: createMock, orderBy: orderByMock });
    firstMock = jest.fn();
    whereSelectMock = jest.fn().mockReturnValue({ first: firstMock });
    whereMock = jest.fn().mockReturnValue({ select: whereSelectMock });

    (db.orm.public.CinemaPartner.select as jest.Mock) = selectMock;
    (db.orm.public.CinemaPartner.where as jest.Mock) = whereMock;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('creates a partner, defaulting apiConfig to null when not provided', async () => {
    createMock.mockResolvedValue(partner());

    const result = await service.create({
      name: 'Cinema X',
      latitude: -22.9711,
      longitude: -43.1822,
    });

    expect(createMock).toHaveBeenCalledWith({
      name: 'Cinema X',
      apiConfig: null,
      latitude: -22.9711,
      longitude: -43.1822,
    });
    expect(result.apiConfig).toBeNull();
  });

  it('lists partners ordered by id', async () => {
    allMock.mockResolvedValue([partner()]);

    const result = await service.list();

    expect(orderByMock).toHaveBeenCalled();
    expect(result).toHaveLength(1);
  });

  it('findOrThrow returns the partner when it exists', async () => {
    firstMock.mockResolvedValue(partner());

    await expect(service.findOrThrow(1)).resolves.toMatchObject({ id: 1 });
  });

  it('findOrThrow throws NotFoundException when it does not exist', async () => {
    firstMock.mockResolvedValue(undefined);

    await expect(service.findOrThrow(999)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  describe('findNearest', () => {
    it('returns null when there are no partners at all', async () => {
      allMock.mockResolvedValue([]);

      await expect(service.findNearest(-22.9, -43.2)).resolves.toBeNull();
    });

    it('returns the only partner when there is just one', async () => {
      allMock.mockResolvedValue([partner({ id: 1 })]);

      const result = await service.findNearest(-22.9, -43.2);

      expect(result?.partner.id).toBe(1);
      expect(result?.distanceKm).toBeGreaterThanOrEqual(0);
    });

    it('picks the closer of several partners, not just the first one', async () => {
      // ~360km from the search point (São Paulo)
      const far = partner({ id: 1, latitude: -22.9068, longitude: -43.1729 });
      // same point as the search coordinates — distance ~0
      const near = partner({ id: 2, latitude: -23.5505, longitude: -46.6333 });
      allMock.mockResolvedValue([far, near]);

      const result = await service.findNearest(-23.5505, -46.6333);

      expect(result?.partner.id).toBe(2);
      expect(result?.distanceKm).toBeCloseTo(0, 3);
    });
  });
});
