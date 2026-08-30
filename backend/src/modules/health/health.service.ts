import { Inject, Injectable } from '@nestjs/common';
import type Redis from 'ioredis';
import { db } from '../../prisma/db';
import { REDIS } from '../../redis/redis.module';

export interface HealthStatus {
  status: 'ok' | 'error';
  uptime: number;
  timestamp: string;
  database: 'ok' | 'error';
  redis: 'ok' | 'error';
}

@Injectable()
export class HealthService {
  constructor(@Inject(REDIS) private readonly redis: Redis) {}

  async check(): Promise<HealthStatus> {
    const [database, redis] = await Promise.all([
      this.checkDatabase(),
      this.checkRedis(),
    ]);
    return {
      status: database === 'ok' && redis === 'ok' ? 'ok' : 'error',
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
      database,
      redis,
    };
  }

  private async checkDatabase(): Promise<'ok' | 'error'> {
    try {
      // Cheap query that forces a real round-trip to Postgres. Swap for a
      // dedicated `db.raw.sql` ping if the User model ever goes away.
      await db.orm.public.User.aggregate((aggregate) => ({
        total: aggregate.count(),
      }));
      return 'ok';
    } catch {
      return 'error';
    }
  }

  private async checkRedis(): Promise<'ok' | 'error'> {
    try {
      await this.redis.ping();
      return 'ok';
    } catch {
      return 'error';
    }
  }
}
