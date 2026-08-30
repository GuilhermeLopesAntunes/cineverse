import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type {
  AuthenticatedUser,
  RequestWithUser,
} from '../guards/jwt-auth.guard';

// Exported separately so it can be unit-tested without going through Nest's
// decorator/DI pipeline — createParamDecorator's return value can't be
// invoked directly in a test.
export function extractCurrentUser(
  _data: unknown,
  context: ExecutionContext,
): AuthenticatedUser | undefined {
  const request = context.switchToHttp().getRequest<RequestWithUser>();
  return request.user;
}

// Populated by JwtAuthGuard; undefined on a @Public() route.
export const CurrentUser = createParamDecorator(extractCurrentUser);
