import type { INestApplicationContext } from '@nestjs/common';
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import Redis from 'ioredis';
import type { Server, ServerOptions } from 'socket.io';
import { redisOptions, REDIS_URL } from '../redis/redis-options';
import { createWsAuthMiddleware } from './ws-auth.middleware';

// Socket.io needs its own pub/sub pair, separate from the app's
// general-purpose Redis client (src/redis/redis.module.ts) and from
// BullMQ's (src/queue/bullmq.config.ts): the subscriber enters Redis's
// dedicated SUBSCRIBE mode for as long as it's connected and can't be
// reused for ordinary commands.
//
// Without this adapter, each server instance keeps its socket rooms purely
// in memory — fine with one instance, but a message from a client on
// instance A would never reach a client on instance B (RNF-01/RNF-07 require
// horizontal scaling; see ARQUITETURA_BACKEND.md section 6).
export class RedisIoAdapter extends IoAdapter {
  private readonly logger = new Logger(RedisIoAdapter.name);
  private readonly jwtService: JwtService;
  private pubClient?: Redis;
  private subClient?: Redis;
  private redisAdapter?: ReturnType<typeof createAdapter>;
  private redisClosed = false;

  constructor(app: INestApplicationContext) {
    super(app);
    this.jwtService = app.get(JwtService);
  }

  connectToRedis(): void {
    this.pubClient = new Redis(REDIS_URL, redisOptions);
    this.subClient = this.pubClient.duplicate();

    this.pubClient.on('error', (err: Error) =>
      this.logger.error(`Redis pub client: ${err.message || err.name}`),
    );
    this.subClient.on('error', (err: Error) =>
      this.logger.error(`Redis sub client: ${err.message || err.name}`),
    );

    this.redisAdapter = createAdapter(this.pubClient, this.subClient);
  }

  createIOServer(port: number, options?: ServerOptions): Server {
    const server = super.createIOServer(port, options) as Server;
    // `server.use()` alone only wires the middleware into the default `/`
    // namespace — a named namespace like `/chat` (created afterwards, via
    // `.of('/chat')`, by Nest's own gateway wiring) never sees it. Socket.io
    // emits `new_namespace` synchronously for every namespace as soon as
    // it's created, default or not, so this is what actually makes the
    // auth middleware apply everywhere.
    const authMiddleware = createWsAuthMiddleware(this.jwtService);
    server.of('/').use(authMiddleware);
    server.on('new_namespace', (namespace) => namespace.use(authMiddleware));
    if (this.redisAdapter) {
      server.adapter(this.redisAdapter);
    }
    return server;
  }

  // Mirrors RedisModule.onApplicationShutdown — these two connections are
  // this adapter's own, Nest's shutdown hooks don't know about them.
  // Nest calls `close()` once per gateway/namespace (BE-19 added a second
  // one, `/chat`, sharing this same adapter instance), so the Redis side of
  // the cleanup has to happen at most once — a second `.quit()` on an
  // already-closed connection throws instead of being a no-op.
  async close(server: Server): Promise<void> {
    await super.close(server);
    if (this.redisClosed) {
      return;
    }
    this.redisClosed = true;
    await Promise.all([this.pubClient?.quit(), this.subClient?.quit()]);
  }
}
