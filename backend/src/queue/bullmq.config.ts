import type { ConnectionOptions } from 'bullmq';

// BullMQ manages its own IORedis connections internally and requires
// `maxRetriesPerRequest: null` for the blocking commands it relies on — that
// setting would be wrong for the app's general-purpose Redis client
// (src/redis/redis.module.ts), so this is a separate connection, not a
// shared one. Parsed from the same REDIS_URL rather than a second env var.
function parseRedisUrl(redisUrl: string): ConnectionOptions {
  const url = new URL(redisUrl);
  return {
    host: url.hostname,
    port: Number(url.port || 6379),
    username: url.username || undefined,
    password: url.password || undefined,
    maxRetriesPerRequest: null,
  };
}

export const bullmqConnection: ConnectionOptions = parseRedisUrl(
  process.env.REDIS_URL ?? 'redis://localhost:6379',
);
