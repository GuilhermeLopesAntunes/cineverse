import { randomUUID } from 'node:crypto';
import type { IncomingMessage, ServerResponse } from 'node:http';
import type { Params } from 'nestjs-pino';

const REQUEST_ID_HEADER = 'x-request-id';

export const pinoLoggerOptions: Params = {
  pinoHttp: {
    level:
      process.env.LOG_LEVEL ??
      (process.env.NODE_ENV === 'production' ? 'info' : 'debug'),
    genReqId: (req: IncomingMessage, res: ServerResponse) => {
      const header = req.headers[REQUEST_ID_HEADER];
      const id =
        typeof header === 'string' && header.length > 0 ? header : randomUUID();
      res.setHeader(REQUEST_ID_HEADER, id);
      return id;
    },
    redact: {
      paths: [
        'req.headers.authorization',
        'req.headers.cookie',
        'res.headers["set-cookie"]',
      ],
      remove: true,
    },
    customLogLevel: (_req, res, err) => {
      if (err || res.statusCode >= 500) return 'error';
      if (res.statusCode >= 400) return 'warn';
      return 'info';
    },
    transport:
      process.env.NODE_ENV !== 'production'
        ? {
            target: 'pino-pretty',
            options: {
              singleLine: true,
              colorize: true,
              translateTime: 'HH:MM:ss.l',
            },
          }
        : undefined,
  },
};
