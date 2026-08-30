import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { CatalogController } from './catalog.controller';
import { CatalogService } from './catalog.service';
import { CatalogSyncProcessor } from './catalog-sync.processor';
import { CatalogSyncScheduler } from './catalog-sync.scheduler';
import { CatalogSyncService } from './catalog-sync.service';
import { CATALOG_SYNC_QUEUE } from './catalog-sync.constants';
import { TmdbClient } from './tmdb/tmdb.client';

@Module({
  imports: [BullModule.registerQueue({ name: CATALOG_SYNC_QUEUE })],
  controllers: [CatalogController],
  providers: [
    TmdbClient,
    CatalogService,
    CatalogSyncService,
    CatalogSyncProcessor,
    CatalogSyncScheduler,
  ],
  exports: [TmdbClient],
})
export class CatalogModule {}
