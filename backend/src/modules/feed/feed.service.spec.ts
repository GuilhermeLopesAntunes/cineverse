import { NotFoundException } from '@nestjs/common';
import { db } from '../../prisma/db';
import { FeedService } from './feed.service';

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        Movie: { where: jest.fn() },
        Review: { select: jest.fn(), aggregate: jest.fn(), where: jest.fn() },
      },
    },
  },
}));

describe('FeedService', () => {
  let service: FeedService;
  let movieFirstMock: jest.Mock;
  let movieWhereMock: jest.Mock;
  let createMock: jest.Mock;
  let allMock: jest.Mock;
  let limitMock: jest.Mock;
  let offsetMock: jest.Mock;
  let orderByMock: jest.Mock;
  let selectMock: jest.Mock;
  let aggregateMock: jest.Mock;
  let reviewFirstMock: jest.Mock;
  let reviewWhereMock: jest.Mock;
  let reviewWhereSelectMock: jest.Mock;

  const sampleReview = {
    id: 1,
    userId: 1,
    movieId: 8,
    text: 'Ótimo filme',
    rating: 5,
    hasSpoiler: false,
    createdAt: 'now',
  };

  beforeEach(() => {
    service = new FeedService();

    movieFirstMock = jest.fn().mockResolvedValue({ id: 8, title: 'Duna' });
    movieWhereMock = jest.fn().mockReturnValue({ first: movieFirstMock });

    createMock = jest.fn();
    allMock = jest.fn().mockResolvedValue([sampleReview]);
    limitMock = jest.fn().mockReturnValue({ all: allMock });
    offsetMock = jest.fn().mockReturnValue({ limit: limitMock });
    orderByMock = jest.fn().mockReturnValue({ offset: offsetMock });
    selectMock = jest
      .fn()
      .mockReturnValue({ create: createMock, orderBy: orderByMock });
    aggregateMock = jest.fn().mockResolvedValue({ total: 1 });

    reviewFirstMock = jest.fn().mockResolvedValue(sampleReview);
    reviewWhereSelectMock = jest
      .fn()
      .mockReturnValue({ first: reviewFirstMock });
    reviewWhereMock = jest
      .fn()
      .mockReturnValue({ select: reviewWhereSelectMock });

    (db.orm.public.Movie.where as jest.Mock) = movieWhereMock;
    (db.orm.public.Review.select as jest.Mock) = selectMock;
    (db.orm.public.Review.aggregate as jest.Mock) = aggregateMock;
    (db.orm.public.Review.where as jest.Mock) = reviewWhereMock;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('create', () => {
    it('checks the movie exists before creating a review', async () => {
      createMock.mockResolvedValue(sampleReview);

      await service.create(1, {
        movieId: 8,
        text: 'Ótimo filme',
        rating: 5,
        hasSpoiler: false,
      });

      expect(movieWhereMock).toHaveBeenCalledWith({ id: 8 });
      expect(createMock).toHaveBeenCalledWith({
        userId: 1,
        movieId: 8,
        text: 'Ótimo filme',
        rating: 5,
        hasSpoiler: false,
      });
    });

    it('throws NotFoundException when the movie does not exist', async () => {
      movieFirstMock.mockResolvedValue(undefined);

      await expect(
        service.create(1, {
          movieId: 999,
          text: 'x',
          rating: 5,
          hasSpoiler: false,
        }),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(createMock).not.toHaveBeenCalled();
    });
  });

  describe('list', () => {
    it('orders by createdAt descending (newest first)', async () => {
      await service.list(1, 20);

      expect(orderByMock).toHaveBeenCalled();
    });

    it('computes offset from the page number', async () => {
      aggregateMock.mockResolvedValue({ total: 100 });

      await service.list(3, 20);

      expect(offsetMock).toHaveBeenCalledWith(40);
      expect(limitMock).toHaveBeenCalledWith(20);
    });

    it('returns items with pagination metadata', async () => {
      aggregateMock.mockResolvedValue({ total: 45 });

      const result = await service.list(2, 20);

      expect(result).toEqual({
        items: [sampleReview],
        page: 2,
        pageSize: 20,
        total: 45,
        totalPages: 3,
      });
    });

    it('reports totalPages as 1 (never 0) for an empty feed', async () => {
      allMock.mockResolvedValue([]);
      aggregateMock.mockResolvedValue({ total: 0 });

      const result = await service.list(1, 20);

      expect(result.totalPages).toBe(1);
      expect(result.items).toEqual([]);
    });

    it('hides the text of spoiler-marked reviews by default', async () => {
      allMock.mockResolvedValue([{ ...sampleReview, hasSpoiler: true }]);

      const result = await service.list(1, 20);

      expect(result.items[0]).toEqual(
        expect.objectContaining({ hasSpoiler: true, text: null }),
      );
    });

    it('keeps the text of non-spoiler reviews visible', async () => {
      const result = await service.list(1, 20);

      expect(result.items[0]).toEqual(
        expect.objectContaining({ hasSpoiler: false, text: 'Ótimo filme' }),
      );
    });
  });

  describe('reveal', () => {
    it('returns the real text regardless of the spoiler flag', async () => {
      reviewFirstMock.mockResolvedValue({ ...sampleReview, hasSpoiler: true });

      const result = await service.reveal(1);

      expect(reviewWhereMock).toHaveBeenCalledWith({ id: 1 });
      expect(result.text).toBe('Ótimo filme');
    });

    it('throws NotFoundException when the review does not exist', async () => {
      reviewFirstMock.mockResolvedValue(undefined);

      await expect(service.reveal(999)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('share', () => {
    it('returns share metadata with the real text for a non-spoiler review', async () => {
      const result = await service.share(1);

      expect(reviewWhereMock).toHaveBeenCalledWith({ id: 1 });
      expect(movieWhereMock).toHaveBeenCalledWith({ id: 8 });
      expect(result.url).toBe('https://cineverse.example/reviews/1');
      expect(result.title).toBe('Resenha de Duna no CineVerse');
      expect(result.text).toContain('Ótimo filme');
      expect(result.text).toContain('Nota: 5/5');
    });

    it('does not leak the text of a spoiler-marked review', async () => {
      reviewFirstMock.mockResolvedValue({ ...sampleReview, hasSpoiler: true });

      const result = await service.share(1);

      expect(result.text).not.toContain('Ótimo filme');
      expect(result.text).toContain('spoiler');
    });

    it('falls back to a generic title when the movie is missing', async () => {
      movieFirstMock.mockResolvedValue(undefined);

      const result = await service.share(1);

      expect(result.title).toBe('Resenha de um filme no CineVerse');
    });

    it('throws NotFoundException when the review does not exist', async () => {
      reviewFirstMock.mockResolvedValue(undefined);

      await expect(service.share(999)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });
});
