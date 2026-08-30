import { db } from '../../prisma/db';
import { CatalogSyncService } from './catalog-sync.service';
import { TmdbClient, TmdbPagedResponse, TmdbMovie } from './tmdb/tmdb.client';

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        Movie: { where: jest.fn(), create: jest.fn() },
      },
    },
  },
}));

function movie(overrides: Partial<TmdbMovie> = {}): TmdbMovie {
  return {
    id: 1,
    title: 'Test Movie',
    overview: 'A movie about tests',
    poster_path: '/poster.jpg',
    release_date: '2026-01-01',
    ...overrides,
  };
}

function page(
  results: TmdbMovie[],
  totalPages = 1,
  pageNum = 1,
): TmdbPagedResponse<TmdbMovie> {
  return {
    page: pageNum,
    results,
    total_pages: totalPages,
    total_results: results.length,
  };
}

describe('CatalogSyncService', () => {
  let service: CatalogSyncService;
  let tmdbClient: { getNowPlaying: jest.Mock };
  let updateMock: jest.Mock;
  let whereMock: jest.Mock;
  let firstMock: jest.Mock;
  let createMock: jest.Mock;

  beforeEach(() => {
    tmdbClient = { getNowPlaying: jest.fn() };
    service = new CatalogSyncService(tmdbClient as unknown as TmdbClient);

    firstMock = jest.fn().mockResolvedValue(undefined);
    updateMock = jest.fn();
    whereMock = jest
      .fn()
      .mockReturnValue({ first: firstMock, update: updateMock });
    createMock = jest.fn();

    (db.orm.public.Movie.where as jest.Mock) = whereMock;
    (db.orm.public.Movie.create as jest.Mock) = createMock;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('creates a new movie with a full TMDB image URL', async () => {
    tmdbClient.getNowPlaying.mockResolvedValue(page([movie()]));

    const result = await service.syncNowPlaying();

    expect(createMock).toHaveBeenCalledWith(
      expect.objectContaining({
        tmdbId: 1,
        title: 'Test Movie',
        synopsis: 'A movie about tests',
        posterUrl: 'https://image.tmdb.org/t/p/w500/poster.jpg',
      }),
    );
    expect(result).toEqual({ pagesFetched: 1, moviesSynced: 1 });
  });

  it('stores a null posterUrl when TMDB has no poster_path', async () => {
    tmdbClient.getNowPlaying.mockResolvedValue(
      page([movie({ poster_path: null })]),
    );

    await service.syncNowPlaying();

    expect(createMock).toHaveBeenCalledWith(
      expect.objectContaining({ posterUrl: null }),
    );
  });

  it('updates instead of creating when a movie with that tmdbId already exists', async () => {
    firstMock.mockResolvedValue({ id: 99, tmdbId: 1 });
    tmdbClient.getNowPlaying.mockResolvedValue(
      page([movie({ title: 'Updated Title' })]),
    );

    await service.syncNowPlaying();

    expect(whereMock).toHaveBeenCalledWith({ tmdbId: 1 });
    expect(updateMock).toHaveBeenCalledWith(
      expect.objectContaining({ title: 'Updated Title' }),
    );
    expect(createMock).not.toHaveBeenCalled();
  });

  it('paginates until TMDB reports no more pages', async () => {
    tmdbClient.getNowPlaying
      .mockResolvedValueOnce(page([movie({ id: 1 })], 3, 1))
      .mockResolvedValueOnce(page([movie({ id: 2 })], 3, 2))
      .mockResolvedValueOnce(page([movie({ id: 3 })], 3, 3));

    const result = await service.syncNowPlaying();

    expect(tmdbClient.getNowPlaying).toHaveBeenCalledTimes(3);
    expect(tmdbClient.getNowPlaying).toHaveBeenNthCalledWith(1, 1);
    expect(tmdbClient.getNowPlaying).toHaveBeenNthCalledWith(2, 2);
    expect(tmdbClient.getNowPlaying).toHaveBeenNthCalledWith(3, 3);
    expect(result).toEqual({ pagesFetched: 3, moviesSynced: 3 });
  });

  it('caps pagination even if TMDB reports an unexpectedly huge total_pages', async () => {
    tmdbClient.getNowPlaying.mockResolvedValue(page([movie()], 500));

    const result = await service.syncNowPlaying();

    expect(tmdbClient.getNowPlaying).toHaveBeenCalledTimes(10);
    expect(result.pagesFetched).toBe(10);
  });
});
