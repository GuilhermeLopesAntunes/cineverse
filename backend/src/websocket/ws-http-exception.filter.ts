import { ArgumentsHost, Catch, HttpException } from '@nestjs/common';
import { BaseWsExceptionFilter } from '@nestjs/websockets';
import type { Socket } from 'socket.io';

// Nest's default WS exception filter only recognizes WsException — any
// HttpException (NotFoundException, ForbiddenException, etc. — the same
// ones REST services already throw, reused as-is by gateways like
// ChatGateway) falls through to a redacted "Internal server error", exactly
// like a genuine bug would. But an HttpException's message is safe and
// expected to reach the client — the same distinction AllExceptionsFilter
// draws for REST — so this maps it to a proper `exception` event instead of
// hiding it. Anything that isn't an HttpException still falls through to
// the default filter's redacted message.
@Catch(HttpException)
export class WsHttpExceptionFilter extends BaseWsExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost): void {
    const client = host.switchToWs().getClient<Socket>();
    const response = exception.getResponse();
    const message =
      typeof response === 'string'
        ? response
        : ((response as { message?: string }).message ?? exception.message);

    client.emit('exception', { status: 'error', message });
  }
}
