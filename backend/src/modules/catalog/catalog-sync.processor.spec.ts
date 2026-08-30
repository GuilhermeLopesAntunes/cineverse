import type { Job } from 'bullmq';
import { CatalogSyncProcessor } from './catalog-sync.processor';
import { CatalogSyncService } from './catalog-sync.service';
import { CATALOG_SYNC_JOB } from './catalog-sync.constants';

describe('CatalogSyncProcessor', () => {
  let processor: CatalogSyncProcessor;
  let syncNowPlaying: jest.Mock;

  beforeEach(() => {
    syncNowPlaying = jest
      .fn()
      .mockResolvedValue({ pagesFetched: 1, moviesSynced: 1 });
    const service = { syncNowPlaying } as unknown as CatalogSyncService;
    processor = new CatalogSyncProcessor(service);
  });

  it('runs the sync for the expected job name', async () => {
    const job = { name: CATALOG_SYNC_JOB } as Job;

    await processor.process(job);

    expect(syncNowPlaying).toHaveBeenCalledTimes(1);
  });

  it('rejects any other job name without touching the sync service', async () => {
    const job = { name: 'some-other-job' } as Job;

    await expect(processor.process(job)).rejects.toThrow(/Unknown job/);
    expect(syncNowPlaying).not.toHaveBeenCalled();
  });

  it('propagates a sync failure so BullMQ retries it, instead of swallowing it', async () => {
    const syncError = new Error('TMDB is down');
    syncNowPlaying.mockRejectedValue(syncError);
    const job = { name: CATALOG_SYNC_JOB } as Job;

    await expect(processor.process(job)).rejects.toBe(syncError);
  });
});
