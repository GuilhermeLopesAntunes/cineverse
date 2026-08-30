import type { Queue } from 'bullmq';
import { CatalogSyncScheduler } from './catalog-sync.scheduler';
import {
  CATALOG_SYNC_JOB,
  CATALOG_SYNC_SCHEDULER_ID,
} from './catalog-sync.constants';

describe('CatalogSyncScheduler', () => {
  const originalInterval = process.env.TMDB_SYNC_INTERVAL_MS;
  let upsertJobScheduler: jest.Mock;
  let add: jest.Mock;
  let scheduler: CatalogSyncScheduler;

  beforeEach(() => {
    upsertJobScheduler = jest.fn().mockResolvedValue(undefined);
    add = jest.fn().mockResolvedValue(undefined);
    const queue = { upsertJobScheduler, add } as unknown as Queue;
    scheduler = new CatalogSyncScheduler(queue);
  });

  afterEach(() => {
    // `process.env.X = undefined` stringifies to "undefined" instead of
    // deleting the key — must `delete` explicitly when there was no
    // original value, or the next test silently inherits a bogus string.
    if (originalInterval === undefined) {
      delete process.env.TMDB_SYNC_INTERVAL_MS;
    } else {
      process.env.TMDB_SYNC_INTERVAL_MS = originalInterval;
    }
  });

  it('registers a recurring schedule using the configured interval', async () => {
    process.env.TMDB_SYNC_INTERVAL_MS = '3600000';

    await scheduler.onModuleInit();

    expect(upsertJobScheduler).toHaveBeenCalledWith(
      CATALOG_SYNC_SCHEDULER_ID,
      { every: 3_600_000 },
      expect.objectContaining({ name: CATALOG_SYNC_JOB }),
    );
  });

  it('falls back to a 6h interval when TMDB_SYNC_INTERVAL_MS is not set', async () => {
    delete process.env.TMDB_SYNC_INTERVAL_MS;

    await scheduler.onModuleInit();

    expect(upsertJobScheduler).toHaveBeenCalledWith(
      CATALOG_SYNC_SCHEDULER_ID,
      { every: 6 * 60 * 60 * 1000 },
      expect.anything(),
    );
  });

  it('also enqueues one immediate run so the catalog is not empty until the first interval', async () => {
    await scheduler.onModuleInit();

    expect(add).toHaveBeenCalledWith(CATALOG_SYNC_JOB, {}, expect.any(Object));
  });
});
