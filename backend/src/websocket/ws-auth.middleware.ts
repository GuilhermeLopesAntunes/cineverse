import { JwtService } from '@nestjs/jwt';
import type { Socket } from 'socket.io';
import { accessTokenConfig } from '../common/config/jwt.config';
import type { AuthenticatedUser } from '../common/guards/jwt-auth.guard';

interface AccessTokenPayload {
  sub: number;
  email: string;
}

export type AuthenticatedSocket = Omit<Socket, 'data'> & {
  data: { user: AuthenticatedUser };
};

type SocketMiddleware = (socket: Socket, next: (err?: Error) => void) => void;

// Same access token as the REST API (JwtAuthGuard) — one login, one token,
// used for both. Namespaces added later (BE-19's `/chat`, BE-22's `/seats`)
// get this for free since it's installed on the raw Socket.io server, not on
// a per-namespace/per-gateway basis.
export function createWsAuthMiddleware(
  jwtService: JwtService,
): SocketMiddleware {
  return (socket, next) => {
    const token = extractToken(socket);
    if (!token) {
      next(new Error('Token de acesso ausente'));
      return;
    }

    jwtService
      .verifyAsync<AccessTokenPayload>(token, {
        secret: accessTokenConfig.secret,
      })
      .then((payload) => {
        (socket as AuthenticatedSocket).data.user = {
          userId: payload.sub,
          email: payload.email,
        };
        next();
      })
      .catch(() => next(new Error('Token de acesso inválido')));
  };
}

// Socket.io's own convention (`io(url, { auth: { token } })`) takes priority
// — it's the documented way to authenticate a handshake, unlike a header
// that most WebSocket clients don't let you set at all. The `Authorization`
// header fallback exists only for parity with the REST guard's tests/tools.
function extractToken(socket: Socket): string | undefined {
  const authToken = socket.handshake.auth?.token as string | undefined;
  if (authToken) {
    return authToken;
  }

  const header = socket.handshake.headers.authorization;
  if (!header) {
    return undefined;
  }
  const [scheme, token] = header.split(' ');
  return scheme === 'Bearer' && token ? token : undefined;
}
