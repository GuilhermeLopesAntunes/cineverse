import { db } from '../../prisma/db';
import { UsersService } from './users.service';

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        UserProfile: { where: jest.fn() },
        FavoriteGenre: { where: jest.fn() },
      },
    },
    transaction: jest.fn(),
  },
}));

interface FakeTx {
  orm: {
    public: {
      UserProfile: { where: jest.Mock; create: jest.Mock };
      FavoriteGenre: { create: jest.Mock };
    };
  };
  sql: {
    public: {
      favoriteGenre: { delete: jest.Mock };
    };
  };
  execute: jest.Mock;
}

function createFakeTx(): FakeTx {
  const deletePlan = { kind: 'delete-plan' };
  const whereBuilder = { build: jest.fn().mockReturnValue(deletePlan) };
  const deleteBuilder = { where: jest.fn().mockReturnValue(whereBuilder) };

  return {
    orm: {
      public: {
        UserProfile: { where: jest.fn(), create: jest.fn() },
        FavoriteGenre: { create: jest.fn() },
      },
    },
    sql: {
      public: {
        favoriteGenre: { delete: jest.fn().mockReturnValue(deleteBuilder) },
      },
    },
    execute: jest.fn(),
  };
}

describe('UsersService', () => {
  let service: UsersService;

  /* eslint-disable @typescript-eslint/unbound-method */
  const profileWhereMock = db.orm.public.UserProfile.where as jest.Mock;
  const genreWhereMock = db.orm.public.FavoriteGenre.where as jest.Mock;
  const transactionMock = db.transaction as unknown as jest.Mock;
  /* eslint-enable @typescript-eslint/unbound-method */

  beforeEach(() => {
    service = new UsersService();
    jest.clearAllMocks();
  });

  describe('getProfile', () => {
    it('returns null when the user has no profile yet', async () => {
      profileWhereMock.mockReturnValue({
        first: jest.fn().mockResolvedValue(undefined),
      });

      await expect(service.getProfile(1)).resolves.toBeNull();
    });

    it('returns the profile with its favorite genres when one exists', async () => {
      profileWhereMock.mockReturnValue({
        first: jest.fn().mockResolvedValue({ id: 10, userId: 1 }),
      });
      const allMock = jest
        .fn()
        .mockResolvedValue([{ genre: 'terror' }, { genre: 'drama' }]);
      genreWhereMock.mockReturnValue({
        select: jest.fn().mockReturnValue({ all: allMock }),
      });

      await expect(service.getProfile(1)).resolves.toEqual({
        userId: 1,
        favoriteGenres: ['terror', 'drama'],
      });
    });
  });

  describe('upsertProfile', () => {
    it('creates the profile row when it does not exist yet, then replaces genres', async () => {
      const tx = createFakeTx();
      tx.orm.public.UserProfile.where.mockReturnValue({
        first: jest.fn().mockResolvedValue(undefined),
      });
      transactionMock.mockImplementation(
        async (callback: (tx: FakeTx) => Promise<void>) => callback(tx),
      );

      const result = await service.upsertProfile(1, {
        favoriteGenres: ['terror', 'drama'],
      });

      expect(tx.orm.public.UserProfile.create).toHaveBeenCalledWith({
        userId: 1,
      });
      // The bug this guards against: a previous version used
      // `tx.orm.FavoriteGenre.where(...).delete()`, which only removed one
      // matching row instead of all of them. The SQL builder + tx.execute
      // path is what's verified to delete every row for the user.
      expect(tx.sql.public.favoriteGenre.delete).toHaveBeenCalled();
      expect(tx.execute).toHaveBeenCalledWith({ kind: 'delete-plan' });
      expect(tx.orm.public.FavoriteGenre.create).toHaveBeenNthCalledWith(1, {
        userId: 1,
        genre: 'terror',
      });
      expect(tx.orm.public.FavoriteGenre.create).toHaveBeenNthCalledWith(2, {
        userId: 1,
        genre: 'drama',
      });
      expect(result).toEqual({
        userId: 1,
        favoriteGenres: ['terror', 'drama'],
      });
    });

    it('does not recreate the profile row when one already exists', async () => {
      const tx = createFakeTx();
      tx.orm.public.UserProfile.where.mockReturnValue({
        first: jest.fn().mockResolvedValue({ id: 10, userId: 1 }),
      });
      transactionMock.mockImplementation(
        async (callback: (tx: FakeTx) => Promise<void>) => callback(tx),
      );

      await service.upsertProfile(1, { favoriteGenres: [] });

      expect(tx.orm.public.UserProfile.create).not.toHaveBeenCalled();
      expect(tx.orm.public.FavoriteGenre.create).not.toHaveBeenCalled();
    });
  });
});
