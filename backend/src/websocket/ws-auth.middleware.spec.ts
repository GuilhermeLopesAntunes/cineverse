import { JwtService } from '@nestjs/jwt';
import type { Socket } from 'socket.io';
import { accessTokenConfig } from '../common/config/jwt.config';
import {
  AuthenticatedSocket,
  createWsAuthMiddleware,
} from './ws-auth.middleware';

function makeSocket(overrides: {
  authToken?: string;
  authorizationHeader?: string;
}): Socket {
  return {
    handshake: {
      auth:
        overrides.authToken !== undefined ? { token: overrides.authToken } : {},
      headers: overrides.authorizationHeader
        ? { authorization: overrides.authorizationHeader }
        : {},
    },
    data: {},
  } as unknown as Socket;
}

describe('createWsAuthMiddleware', () => {
  let jwtService: JwtService;
  let middleware: ReturnType<typeof createWsAuthMiddleware>;

  beforeEach(() => {
    jwtService = new JwtService();
    middleware = createWsAuthMiddleware(jwtService);
  });

  async function sign(payload: {
    sub: number;
    email: string;
  }): Promise<string> {
    return jwtService.signAsync(payload, {
      secret: accessTokenConfig.secret,
      expiresIn: accessTokenConfig.expiresIn,
    });
  }

  it('authenticates via handshake.auth.token and attaches the user', (done) => {
    void sign({ sub: 7, email: 'a@example.com' }).then((token) => {
      const socket = makeSocket({ authToken: token });

      middleware(socket, (err) => {
        expect(err).toBeUndefined();
        expect((socket as AuthenticatedSocket).data.user).toEqual({
          userId: 7,
          email: 'a@example.com',
        });
        done();
      });
    });
  });

  it('falls back to the Authorization header when no auth.token is sent', (done) => {
    void sign({ sub: 9, email: 'b@example.com' }).then((token) => {
      const socket = makeSocket({ authorizationHeader: `Bearer ${token}` });

      middleware(socket, (err) => {
        expect(err).toBeUndefined();
        expect((socket as AuthenticatedSocket).data.user.userId).toBe(9);
        done();
      });
    });
  });

  it('rejects a connection with no token at all', (done) => {
    const socket = makeSocket({});

    middleware(socket, (err) => {
      expect(err).toBeInstanceOf(Error);
      expect(err?.message).toBe('Token de acesso ausente');
      done();
    });
  });

  it('rejects an invalid token', (done) => {
    const socket = makeSocket({ authToken: 'not-a-real-token' });

    middleware(socket, (err) => {
      expect(err).toBeInstanceOf(Error);
      expect(err?.message).toBe('Token de acesso inválido');
      done();
    });
  });

  it('rejects a token signed with the wrong secret', (done) => {
    const wrongService = new JwtService();
    void wrongService
      .signAsync(
        { sub: 1, email: 'x@example.com' },
        { secret: 'wrong-secret', expiresIn: '15m' },
      )
      .then((token) => {
        const socket = makeSocket({ authToken: token });

        middleware(socket, (err) => {
          expect(err).toBeInstanceOf(Error);
          done();
        });
      });
  });
});
