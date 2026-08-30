import type { RedisOptions } from 'ioredis';

export const REDIS_URL = process.env.REDIS_URL ?? 'redis://localhost:6379';

export const redisOptions: RedisOptions = {
  // Backoff capped at 5s; ioredis keeps retrying forever unless told
  // otherwise, so the app never crashes just because Redis is unreachable.
  retryStrategy: (times: number) => Math.min(times * 200, 5000),
  maxRetriesPerRequest: 3,
};
