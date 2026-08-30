import { db } from '../../prisma/db';
import { CatalogService } from './catalog.service';

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        Movie: { orderBy: jest.fn(), aggregate: jest.fn(), where: jest.fn() },
      },
    },
  },
}));

describe('CatalogService', () => {
  let service: CatalogService;
  let allMock: jest.Mock;
  let limitMock: jest.Mock;
  let offsetMock: jest.Mock;
  let orderByMock: jest.Mock;
  let aggregateMock: jest.Mock;
  let whereMock: jest.Mock;

  const sampleMovies = [
    {
      id: 1,
      tmdbId: 10,
      title: 'A Movie',
      synopsis: null,
      posterUrl: null,
      cachedAt: 'now',
      releaseDate: null,
    },
  ];

  beforeEach(() => {
    service = new CatalogService();

    allMock = jest.fn().mockResolvedValue(sampleMovies);
    limitMock = jest.fn().mockReturnValue({ all: allMock });
    offsetMock = jest.fn().mockReturnValue({ limit: limitMock });
    orderByMock = jest.fn().mockReturnValue({ offset: offsetMock });
    aggregateMock = jest.fn().mockResolvedValue({ total: 0 });
    whereMock = jest.fn();

    // `.where()` devolve o mesmo objeto de query — é o que permite
    // `.where().where()` (janela de "lançamento") encadear normalmente.
    const query = {
      orderBy: orderByMock,
      aggregate: aggregateMock,
      where: whereMock,
    };
    whereMock.mockReturnValue(query);

    (db.orm.public.Movie.orderBy as jest.Mock) = orderByMock;
    (db.orm.public.Movie.aggregate as jest.Mock) = aggregateMock;
    (db.orm.public.Movie.where as jest.Mock) = whereMock;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('computes offset 0 for the first page', async () => {
    aggregateMock.mockResolvedValue({ total: 100 });

    await service.listMovies(1, 20);

    expect(offsetMock).toHaveBeenCalledWith(0);
    expect(limitMock).toHaveBeenCalledWith(20);
  });

  it('computes the correct offset for a later page', async () => {
    aggregateMock.mockResolvedValue({ total: 100 });

    await service.listMovies(3, 20);

    expect(offsetMock).toHaveBeenCalledWith(40);
  });

  it('returns items alongside page metadata, rounding totalPages up', async () => {
    aggregateMock.mockResolvedValue({ total: 45 });

    const result = await service.listMovies(2, 20);

    expect(result).toEqual({
      items: sampleMovies,
      page: 2,
      pageSize: 20,
      total: 45,
      totalPages: 3,
    });
  });

  it('reports totalPages as 1 (never 0) for an empty catalog', async () => {
    allMock.mockResolvedValue([]);
    aggregateMock.mockResolvedValue({ total: 0 });

    const result = await service.listMovies(1, 20);

    expect(result.totalPages).toBe(1);
    expect(result.items).toEqual([]);
  });

  it('não filtra por releaseDate quando nenhuma categoria é informada', async () => {
    aggregateMock.mockResolvedValue({ total: 1 });

    await service.listMovies(1, 20);

    expect(whereMock).not.toHaveBeenCalled();
  });

  it('"em_breve" aplica uma única condição de data (releaseDate no futuro)', async () => {
    aggregateMock.mockResolvedValue({ total: 1 });

    await service.listMovies(1, 20, 'em_breve');

    expect(whereMock).toHaveBeenCalledTimes(1);
    expect(whereMock).toHaveBeenCalledWith(expect.any(Function));
  });

  it('"lancamento" combina duas condições de data (janela de 21 dias)', async () => {
    aggregateMock.mockResolvedValue({ total: 1 });

    await service.listMovies(1, 20, 'lancamento');

    expect(whereMock).toHaveBeenCalledTimes(2);
  });

  it('"em_cartaz" aplica uma única condição de data (fora da janela de lançamento)', async () => {
    aggregateMock.mockResolvedValue({ total: 1 });

    await service.listMovies(1, 20, 'em_cartaz');

    expect(whereMock).toHaveBeenCalledTimes(1);
  });
});
