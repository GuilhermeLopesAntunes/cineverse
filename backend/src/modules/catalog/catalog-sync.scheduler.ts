import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import type { Queue } from 'bullmq';
import {
  CATALOG_SYNC_JOB,
  CATALOG_SYNC_QUEUE,
  CATALOG_SYNC_SCHEDULER_ID,
  CATALOG_SYNC_UPCOMING_JOB,
  CATALOG_SYNC_UPCOMING_SCHEDULER_ID,
} from './catalog-sync.constants';

const DEFAULT_SYNC_INTERVAL_MS = 6 * 60 * 60 * 1000; // 6h

// Registers the recurring schedule once at boot. `upsertJobScheduler` is
// idempotent by its id — re-registering the same schedule on every app
// restart updates it in place rather than piling up duplicates.
@Injectable()
export class CatalogSyncScheduler implements OnModuleInit {
  private readonly logger = new Logger(CatalogSyncScheduler.name);

  constructor(@InjectQueue(CATALOG_SYNC_QUEUE) private readonly queue: Queue) {}

  async onModuleInit(): Promise<void> {
    const intervalMs = Number(
      process.env.TMDB_SYNC_INTERVAL_MS ?? DEFAULT_SYNC_INTERVAL_MS,
    );
    const jobOptions = {
      attempts: 2,
      removeOnComplete: true,
      removeOnFail: 50,
    };

    await this.queue.upsertJobScheduler(
      CATALOG_SYNC_SCHEDULER_ID,
      { every: intervalMs },
      { name: CATALOG_SYNC_JOB, opts: jobOptions },
    );
    await this.queue.upsertJobScheduler(
      CATALOG_SYNC_UPCOMING_SCHEDULER_ID,
      { every: intervalMs },
      { name: CATALOG_SYNC_UPCOMING_JOB, opts: jobOptions },
    );

    // The scheduler's own first run is delayed by `intervalMs` — fire one
    // immediately too, so the catalog isn't empty until then (e.g. a fresh
    // deploy shouldn't have to wait 6h for its first movie).
    await this.queue.add(CATALOG_SYNC_JOB, {}, jobOptions);
    await this.queue.add(CATALOG_SYNC_UPCOMING_JOB, {}, jobOptions);

    this.logger.log(`Catalog sync scheduled every ${intervalMs}ms`);
  }
}
