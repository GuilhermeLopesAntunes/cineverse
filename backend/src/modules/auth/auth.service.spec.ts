import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { db } from '../../prisma/db';
import { AuthService } from './auth.service';
import {
  accessTokenConfig,
  refreshTokenConfig,
} from '../../common/config/jwt.config';

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        User: {
          select: jest.fn(),
          where: jest.fn(),
        },
      },
    },
  },
}));

jest.mock('bcryptjs', () => ({
  hash: jest.fn(),
  hashSync: jest.fn(() => 'dummy-hash'),
  compare: jest.fn(),
}));

describe('AuthService', () => {
  let service: AuthService;
  let jwtService: JwtService;
  let createMock: jest.Mock;
  let selectMock: jest.Mock;
  let whereMock: jest.Mock;
  let whereSelectMock: jest.Mock;
  let firstMock: jest.Mock;
  let hashMock: jest.Mock;
  let compareMock: jest.Mock;

  beforeEach(() => {
    jwtService = new JwtService();
    service = new AuthService(jwtService);

    createMock = jest.fn();
    whereSelectMock = jest.fn();
    firstMock = jest.fn();

    // These are plain jest.fn() mocks on a mocked module, not real bound
    // methods — safe to reference unbound.
    /* eslint-disable @typescript-eslint/unbound-method */
    selectMock = db.orm.public.User.select as jest.Mock;
    whereMock = db.orm.public.User.where as jest.Mock;
    hashMock = bcrypt.hash as jest.Mock;
    compareMock = bcrypt.compare as jest.Mock;
    /* eslint-enable @typescript-eslint/unbound-method */

    selectMock.mockReturnValue({ create: createMock });
    whereMock.mockReturnValue({ select: whereSelectMock });
    whereSelectMock.mockReturnValue({ first: firstMock });
    hashMock.mockResolvedValue('hashed-password');
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('register', () => {
    it('hashes the password and returns the created user without the hash', async () => {
      const createdUser = {
        id: 1,
        email: 'alice@example.com',
        name: 'Alice',
        createdAt: '2026-01-01T00:00:00.000Z',
      };
      createMock.mockResolvedValue(createdUser);

      const result = await service.register({
        email: 'alice@example.com',
        password: 'supersecret123',
        name: 'Alice',
      });

      expect(hashMock).toHaveBeenCalledWith('supersecret123', 10);
      expect(selectMock).toHaveBeenCalledWith(
        'id',
        'email',
        'name',
        'createdAt',
      );
      expect(createMock).toHaveBeenCalledWith({
        email: 'alice@example.com',
        name: 'Alice',
        passwordHash: 'hashed-password',
      });
      expect(result).toEqual(createdUser);
    });

    it('translates a unique-constraint violation into a ConflictException', async () => {
      createMock.mockRejectedValue({ sqlState: '23505' });

      await expect(
        service.register({
          email: 'dup@example.com',
          password: 'supersecret123',
        }),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('rethrows errors unrelated to a unique-constraint violation', async () => {
      const dbError = new Error('connection lost');
      createMock.mockRejectedValue(dbError);

      await expect(
        service.register({
          email: 'x@example.com',
          password: 'supersecret123',
        }),
      ).rejects.toBe(dbError);
    });
  });

  describe('login', () => {
    it('returns a valid access + refresh token pair for correct credentials', async () => {
      firstMock.mockResolvedValue({
        id: 42,
        email: 'alice@example.com',
        passwordHash: 'stored-hash',
      });
      compareMock.mockResolvedValue(true);

      const result = await service.login({
        email: 'alice@example.com',
        password: 'supersecret123',
      });

      expect(whereMock).toHaveBeenCalledWith({ email: 'alice@example.com' });
      expect(compareMock).toHaveBeenCalledWith('supersecret123', 'stored-hash');

      const accessPayload = await jwtService.verifyAsync<{
        sub: number;
        email: string;
      }>(result.accessToken, { secret: accessTokenConfig.secret });
      expect(accessPayload).toMatchObject({
        sub: 42,
        email: 'alice@example.com',
      });

      const refreshPayload = await jwtService.verifyAsync<{ sub: number }>(
        result.refreshToken,
        { secret: refreshTokenConfig.secret },
      );
      expect(refreshPayload).toMatchObject({ sub: 42 });
    });

    it('rejects a wrong password with a generic UnauthorizedException', async () => {
      firstMock.mockResolvedValue({
        id: 42,
        email: 'alice@example.com',
        passwordHash: 'stored-hash',
      });
      compareMock.mockResolvedValue(false);

      await expect(
        service.login({ email: 'alice@example.com', password: 'wrong' }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('rejects a non-existent e-mail with the same generic UnauthorizedException', async () => {
      firstMock.mockResolvedValue(undefined);
      compareMock.mockResolvedValue(false);

      await expect(
        service.login({ email: 'ghost@example.com', password: 'whatever123' }),
      ).rejects.toBeInstanceOf(UnauthorizedException);

      // Still hashes against a dummy value — an attacker can't tell "no such
      // user" from "wrong password" by response timing or code path.
      expect(compareMock).toHaveBeenCalledWith('whatever123', 'dummy-hash');
    });
  });

  describe('token expiry (acceptance criterion: an expired token is rejected)', () => {
    it('rejects an access token that has already expired', async () => {
      const expiredToken = await jwtService.signAsync(
        { sub: 1, email: 'alice@example.com' },
        { secret: accessTokenConfig.secret, expiresIn: -10 },
      );

      await expect(
        jwtService.verifyAsync(expiredToken, {
          secret: accessTokenConfig.secret,
        }),
      ).rejects.toThrow('jwt expired');
    });

    it('rejects a refresh token that has already expired', async () => {
      const expiredToken = await jwtService.signAsync(
        { sub: 1 },
        { secret: refreshTokenConfig.secret, expiresIn: -10 },
      );

      await expect(
        jwtService.verifyAsync(expiredToken, {
          secret: refreshTokenConfig.secret,
        }),
      ).rejects.toThrow('jwt expired');
    });
  });
});
