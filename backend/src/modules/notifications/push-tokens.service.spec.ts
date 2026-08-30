import { db } from '../../prisma/db';
import { PushTokensService } from './push-tokens.service';

interface Chain {
  select: jest.Mock;
  update: jest.Mock;
  first: jest.Mock;
}

function makeChain(): Chain {
  const chain = {} as Chain;
  chain.select = jest.fn().mockReturnValue(chain);
  chain.update = jest.fn().mockResolvedValue(undefined);
  chain.first = jest.fn();
  return chain;
}

const sampleToken = {
  id: 1,
  userId: 42,
  token: 'fcm-token-abc',
  platform: 'android',
  createdAt: 'now',
};

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        PushToken: {},
      },
    },
  },
}));

describe('PushTokensService', () => {
  let service: PushTokensService;
  let whereChain: Chain;
  let whereMock: jest.Mock;
  let createMock: jest.Mock;

  beforeEach(() => {
    service = new PushTokensService();

    whereChain = makeChain();
    whereChain.first.mockResolvedValue(undefined); // no existing token, by default
    whereMock = jest.fn().mockReturnValue(whereChain);
    (db.orm.public.PushToken as unknown as { where: jest.Mock }).where =
      whereMock;

    createMock = jest.fn().mockResolvedValue(sampleToken);
    (db.orm.public.PushToken as unknown as { create: jest.Mock }).create =
      createMock;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('register', () => {
    it('creates a new row when the token has never been seen before', async () => {
      whereChain.first
        .mockResolvedValueOnce(undefined) // existence check
        .mockResolvedValueOnce(sampleToken); // final read-back

      const result = await service.register(42, {
        token: 'fcm-token-abc',
        platform: 'android',
      });

      expect(createMock).toHaveBeenCalledWith({
        userId: 42,
        token: 'fcm-token-abc',
        platform: 'android',
      });
      expect(whereChain.update).not.toHaveBeenCalled();
      expect(result).toEqual(sampleToken);
    });

    it('re-points an already-registered token at the current user/platform instead of creating a duplicate', async () => {
      whereChain.first
        .mockResolvedValueOnce({ ...sampleToken, userId: 7, platform: 'ios' }) // existence check: owned by someone else
        .mockResolvedValueOnce({ ...sampleToken, platform: 'ios' }); // final read-back

      const result = await service.register(42, {
        token: 'fcm-token-abc',
        platform: 'ios',
      });

      expect(createMock).not.toHaveBeenCalled();
      expect(whereChain.update).toHaveBeenCalledWith({
        userId: 42,
        platform: 'ios',
      });
      expect(result).toEqual({ ...sampleToken, platform: 'ios' });
    });

    it('falls back to updating when a race loses to another registration of the same token', async () => {
      whereChain.first
        .mockResolvedValueOnce(undefined) // existence check said "new"
        .mockResolvedValueOnce(sampleToken); // final read-back, after the race
      createMock.mockRejectedValue({ sqlState: '23505' });

      const result = await service.register(42, {
        token: 'fcm-token-abc',
        platform: 'android',
      });

      expect(whereChain.update).toHaveBeenCalledWith({
        userId: 42,
        platform: 'android',
      });
      expect(result).toEqual(sampleToken);
    });

    it('rethrows a create error that is not a unique violation', async () => {
      whereChain.first.mockResolvedValueOnce(undefined);
      const dbError = new Error('connection lost');
      createMock.mockRejectedValue(dbError);

      await expect(
        service.register(42, { token: 'fcm-token-abc', platform: 'android' }),
      ).rejects.toBe(dbError);
    });
  });
});
