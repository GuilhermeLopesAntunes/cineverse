// Must run before any other local import — several modules (jwt.config.ts,
// prisma/db.ts) read process.env at module-load time, so .env has to be
// loaded before those modules are first required, not as a side effect
// buried inside one of them.
import 'dotenv/config';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { Logger, LoggerErrorInterceptor } from 'nestjs-pino';
import { AppModule } from './app.module';
import { RedisIoAdapter } from './websocket/redis-io.adapter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  app.useLogger(app.get(Logger));
  app.useGlobalInterceptors(new LoggerErrorInterceptor());
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // strips properties not declared on the DTO
      forbidNonWhitelisted: true, // ...and rejects the request if it sent any
      transform: true, // lets DTOs use real types (e.g. numbers) from string input
    }),
  );
  // Must connect before any @WebSocketGateway() spins up its IO server
  // (BE-19's /chat, BE-22's /seats) — createIOServer() attaches whatever
  // Redis adapter is already built at that point, it doesn't await one.
  const redisIoAdapter = new RedisIoAdapter(app);
  redisIoAdapter.connectToRedis();
  app.useWebSocketAdapter(redisIoAdapter);
  // Lets RedisModule.onApplicationShutdown close the connection cleanly on
  // SIGTERM/SIGINT instead of the process dying with it still open.
  app.enableShutdownHooks();
  // Health checks are hit by infra probes, not API clients — keep them
  // outside the versioned surface. Nest logs a one-time "Unsupported route
  // path" warning here on Express 5 (path-to-regexp v7) — it self-converts
  // the internal wildcard and both routes work; see CLAUDE.md.
  app.setGlobalPrefix('api/v1', { exclude: ['health'] });
  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
