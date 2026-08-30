import { NotFoundException } from '@nestjs/common';
import { db } from '../../prisma/db';
import { PartnersService } from './partners.service';
import { RoomsService } from './rooms.service';
import { SessionsService } from './sessions.service';

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        Movie: { where: jest.fn() },
        Session: { select: jest.fn(), where: jest.fn() },
      },
    },
  },
}));

describe('SessionsService', () => {
  let service: SessionsService;
  let roomsService: { findOrThrow: jest.Mock; listByPartner: jest.Mock };
  let partnersService: { findNearest: jest.Mock };
  let movieFirstMock: jest.Mock;
  let movieWhereMock: jest.Mock;
  let createMock: jest.Mock;
  let allMock: jest.Mock;
  let orderByMock: jest.Mock;
  let selectMock: jest.Mock;
  let sessionWhereMock: jest.Mock;

  const dto = {
    movieId: 8,
    roomId: 1,
    datetime: '2026-09-01T19:30:00Z',
    priceCents: 3500,
  };

  beforeEach(() => {
    roomsService = {
      findOrThrow: jest.fn().mockResolvedValue({ id: 1 }),
      listByPartner: jest
        .fn()
        .mockResolvedValue([{ id: 1, partnerId: 1, name: 'Sala 1' }]),
    };
    partnersService = {
      findNearest: jest.fn().mockResolvedValue({
        partner: { id: 1, name: 'Cinema X' },
        distanceKm: 1.5,
      }),
    };
    service = new SessionsService(
      roomsService as unknown as RoomsService,
      partnersService as unknown as PartnersService,
    );

    movieFirstMock = jest.fn().mockResolvedValue({ id: 8 });
    movieWhereMock = jest.fn().mockReturnValue({ first: movieFirstMock });

    createMock = jest.fn();
    allMock = jest.fn().mockResolvedValue([]);
    orderByMock = jest.fn().mockReturnValue({ all: allMock });
    selectMock = jest
      .fn()
      .mockReturnValue({ create: createMock, orderBy: orderByMock });

    // Chainable: db.orm.public.Session.where(...).where(...).select(...) —
    // findNearby ANDs two predicates before selecting, list() only ever
    // chains one, so the mock needs to support both depths.
    const chainable = { where: jest.fn(), select: selectMock };
    chainable.where.mockReturnValue(chainable);
    sessionWhereMock = chainable.where;

    (db.orm.public.Movie.where as jest.Mock) = movieWhereMock;
    (db.orm.public.Session.select as jest.Mock) = selectMock;
    (db.orm.public.Session.where as jest.Mock) = sessionWhereMock;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('create', () => {
    it('checks the room and the movie exist before creating a session', async () => {
      createMock.mockResolvedValue({ id: 1, ...dto });

      await service.create(dto);

      expect(roomsService.findOrThrow).toHaveBeenCalledWith(1);
      expect(movieWhereMock).toHaveBeenCalledWith({ id: 8 });
      expect(createMock).toHaveBeenCalledWith(dto);
    });

    it('throws NotFoundException when the movie does not exist', async () => {
      movieFirstMock.mockResolvedValue(undefined);

      await expect(service.create(dto)).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(createMock).not.toHaveBeenCalled();
    });
  });

  describe('list', () => {
    it('lists all sessions when no roomId filter is given', async () => {
      await service.list();

      expect(sessionWhereMock).not.toHaveBeenCalled();
      expect(selectMock).toHaveBeenCalled();
    });

    it('filters by roomId when given', async () => {
      await service.list(1);

      expect(sessionWhereMock).toHaveBeenCalledWith({ roomId: 1 });
    });
  });

  describe('findNearby', () => {
    it('throws NotFoundException when no partner is registered at all', async () => {
      partnersService.findNearest.mockResolvedValue(null);

      await expect(service.findNearby(-22.9, -43.2)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('returns an empty session list without querying Session when the partner has no rooms', async () => {
      roomsService.listByPartner.mockResolvedValue([]);

      const result = await service.findNearby(-22.9, -43.2);

      expect(result.sessions).toEqual([]);
      expect(sessionWhereMock).not.toHaveBeenCalled();
    });

    it('filters by the partner rooms and only future sessions, returning distance', async () => {
      roomsService.listByPartner.mockResolvedValue([{ id: 1 }, { id: 2 }]);
      allMock.mockResolvedValue([
        {
          id: 10,
          movieId: 1,
          roomId: 1,
          datetime: '2027-01-01T00:00:00Z',
          priceCents: 1000,
        },
      ]);

      const result = await service.findNearby(-22.9, -43.2);

      expect(partnersService.findNearest).toHaveBeenCalledWith(-22.9, -43.2);
      expect(roomsService.listByPartner).toHaveBeenCalledWith(1);
      // Two ANDed predicates: roomId.in([...]) and datetime.gte(now).
      expect(sessionWhereMock).toHaveBeenCalledTimes(2);
      expect(result.partner).toEqual({
        id: 1,
        name: 'Cinema X',
        distanceKm: 1.5,
      });
      expect(result.sessions).toHaveLength(1);
    });
  });
});
