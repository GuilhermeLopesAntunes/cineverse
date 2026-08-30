import {
  Global,
  Inject,
  Logger,
  Module,
  OnApplicationShutdown,
} from '@nestjs/common';
import Redis from 'ioredis';
import { redisOptions, REDIS_URL } from './redis-options';

export const REDIS = Symbol('REDIS');

@Global()
@Module({
  providers: [
    {
      provide: REDIS,
      useFactory: (): Redis => {
        const logger = new Logger('RedisModule');
        const client = new Redis(REDIS_URL, redisOptions);

        client.on('connect', () => logger.log('Connecting to Redis...'));
        client.on('ready', () => logger.log('Redis connection ready'));
        client.on('reconnecting', (delay: number) =>
          logger.warn(`Redis connection lost, reconnecting in ${delay}ms`),
        );
        // Some Redis connection errors (e.g. Node's AggregateError for
        // ECONNREFUSED) carry an empty `message` — fall back to the name so
        // the log line is never blank.
        client.on('error', (err: Error) =>
          logger.error(err.message || err.name, err.stack),
        );
        client.on('close', () => logger.warn('Redis connection closed'));

        return client;
      },
    },
  ],
  exports: [REDIS],
})
export class RedisModule implements OnApplicationShutdown {
  constructor(@Inject(REDIS) private readonly client: Redis) {}

  async onApplicationShutdown(): Promise<void> {
    await this.client.quit();
  }
}
