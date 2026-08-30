import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import type { Job } from 'bullmq';
import { CatalogSyncService } from './catalog-sync.service';
import {
  CATALOG_SYNC_JOB,
  CATALOG_SYNC_QUEUE,
  CATALOG_SYNC_UPCOMING_JOB,
} from './catalog-sync.constants';

@Processor(CATALOG_SYNC_QUEUE)
export class CatalogSyncProcessor extends WorkerHost {
  private readonly logger = new Logger(CatalogSyncProcessor.name);

  constructor(private readonly catalogSyncService: CatalogSyncService) {
    super();
  }

  async process(job: Job): Promise<void> {
    if (job.name !== CATALOG_SYNC_JOB && job.name !== CATALOG_SYNC_UPCOMING_JOB) {
      // Exhaustive-by-convention: this queue only ever carries these two job
      // types today. Fail loudly instead of silently ignoring an unknown job.
      throw new Error(
        `Unknown job "${job.name}" on queue "${CATALOG_SYNC_QUEUE}"`,
      );
    }

    try {
      if (job.name === CATALOG_SYNC_JOB) {
        await this.catalogSyncService.syncNowPlaying();
      } else {
        await this.catalogSyncService.syncUpcoming();
      }
    } catch (err) {
      // Never let a TMDB outage take the whole app down or wipe the local
      // catalog — log and let BullMQ's own retry/backoff (set on the job)
      // try again later. The last successfully cached data stays served in
      // the meantime (ARQUITETURA_BACKEND.md § 7 fallback).
      this.logger.error(
        `Catalog sync failed: ${err instanceof Error ? err.message : String(err)}`,
      );
      throw err;
    }
  }
}
