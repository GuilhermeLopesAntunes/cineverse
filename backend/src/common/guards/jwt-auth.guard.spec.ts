import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { JwtAuthGuard, RequestWithUser } from './jwt-auth.guard';

function createContext(headers: Record<string, string> = {}): {
  context: ExecutionContext;
  request: RequestWithUser;
} {
  const request = { headers } as RequestWithUser;
  const context = {
    getHandler: () => jest.fn(),
    getClass: () => jest.fn(),
    switchToHttp: () => ({
      getRequest: () => request,
    }),
  } as unknown as ExecutionContext;
  return { context, request };
}

describe('JwtAuthGuard', () => {
  let guard: JwtAuthGuard;
  let reflector: Reflector;
  let jwtService: JwtService;
  let getAllAndOverrideMock: jest.Mock;
  let verifyAsyncMock: jest.Mock;

  beforeEach(() => {
    reflector = new Reflector();
    getAllAndOverrideMock = jest.fn();
    reflector.getAllAndOverride = getAllAndOverrideMock;

    jwtService = new JwtService();
    verifyAsyncMock = jest.fn();
    jwtService.verifyAsync = verifyAsyncMock;

    guard = new JwtAuthGuard(reflector, jwtService);
  });

  it('allows a @Public() route through without checking the token', async () => {
    getAllAndOverrideMock.mockReturnValue(true);
    const { context } = createContext();

    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(verifyAsyncMock).not.toHaveBeenCalled();
  });

  it('rejects a request with no Authorization header', async () => {
    getAllAndOverrideMock.mockReturnValue(false);
    const { context } = createContext();

    await expect(guard.canActivate(context)).rejects.toThrow(
      new UnauthorizedException('Token de acesso ausente'),
    );
  });

  it('rejects a header that is not a Bearer token', async () => {
    getAllAndOverrideMock.mockReturnValue(false);
    const { context } = createContext({ authorization: 'Basic somevalue' });

    await expect(guard.canActivate(context)).rejects.toThrow(
      new UnauthorizedException('Token de acesso ausente'),
    );
  });

  it('rejects an expired token with a specific message', async () => {
    getAllAndOverrideMock.mockReturnValue(false);
    const expiredError = new Error('jwt expired');
    expiredError.name = 'TokenExpiredError';
    verifyAsyncMock.mockRejectedValue(expiredError);
    const { context } = createContext({
      authorization: 'Bearer expired.token.here',
    });

    await expect(guard.canActivate(context)).rejects.toThrow(
      new UnauthorizedException('Token de acesso expirado'),
    );
  });

  it('rejects a malformed/invalid-signature token with a generic message', async () => {
    getAllAndOverrideMock.mockReturnValue(false);
    verifyAsyncMock.mockRejectedValue(new Error('invalid signature'));
    const { context } = createContext({ authorization: 'Bearer garbage' });

    await expect(guard.canActivate(context)).rejects.toThrow(
      new UnauthorizedException('Token de acesso inválido'),
    );
  });

  it('attaches the decoded user to the request and allows the call through', async () => {
    getAllAndOverrideMock.mockReturnValue(false);
    verifyAsyncMock.mockResolvedValue({ sub: 42, email: 'alice@example.com' });
    const { context, request } = createContext({
      authorization: 'Bearer valid.token.here',
    });

    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(request.user).toEqual({ userId: 42, email: 'alice@example.com' });
  });
});
