import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { PinoLogger } from 'nestjs-pino';

interface ApiErrorBody {
  statusCode: number;
  error: string;
  message: string | string[];
  requestId: string;
  timestamp: string;
  path: string;
}

const GENERIC_MESSAGE = 'Internal server error';
const INTERNAL_SERVER_ERROR: number = HttpStatus.INTERNAL_SERVER_ERROR;

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  constructor(private readonly logger: PinoLogger) {
    this.logger.setContext(AllExceptionsFilter.name);
  }

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const request = ctx.getRequest<Request>();
    const response = ctx.getResponse<Response>();
    // pino-http's genReqId (see common/logger/pino-options.ts) always returns
    // a string; the wider `ReqId` type is what forces the explicit guard.
    const requestId = typeof request.id === 'string' ? request.id : '';

    const isHttpException = exception instanceof HttpException;
    const statusCode: number = isHttpException
      ? exception.getStatus()
      : INTERNAL_SERVER_ERROR;

    // Only HttpException messages are safe to expose — anything else (bugs,
    // driver errors, ...) could leak internals, so it's replaced with a
    // generic message on the response. Full detail still goes to the log.
    const { error, message } = isHttpException
      ? this.describeHttpException(exception, statusCode)
      : { error: 'Internal Server Error', message: GENERIC_MESSAGE };

    if (statusCode >= INTERNAL_SERVER_ERROR) {
      this.logger.error(
        { err: exception, requestId, path: request.url },
        'Unhandled exception',
      );
    } else {
      this.logger.warn(
        { requestId, path: request.url, statusCode },
        typeof message === 'string' ? message : JSON.stringify(message),
      );
    }

    const body: ApiErrorBody = {
      statusCode,
      error,
      message,
      requestId,
      timestamp: new Date().toISOString(),
      path: request.url,
    };

    response.status(statusCode).json(body);
  }

  private describeHttpException(
    exception: HttpException,
    statusCode: number,
  ): { error: string; message: string | string[] } {
    const payload = exception.getResponse();
    if (typeof payload === 'string') {
      return { error: exception.name, message: payload };
    }
    const record = payload as Record<string, unknown>;
    const message =
      (record.message as string | string[] | undefined) ?? exception.message;
    const error =
      (record.error as string | undefined) ??
      HttpStatus[statusCode] ??
      exception.name;
    return { error, message };
  }
}
