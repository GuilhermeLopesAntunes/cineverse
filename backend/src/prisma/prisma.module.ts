import { Global, Module, OnApplicationShutdown } from '@nestjs/common';
import { db } from './db';

export const DB = Symbol('DB');

@Global()
@Module({
  providers: [{ provide: DB, useValue: db }],
  exports: [DB],
})
export class PrismaModule implements OnApplicationShutdown {
  // `db` is a plain module-level singleton (src/prisma/db.ts), not something
  // Nest constructs — nothing was ever closing its connection pool on
  // shutdown. Never surfaced before because no e2e test actually ran a real
  // query until BE-23's concurrency test; that one leaked an open handle
  // that only failed a Jest worker's graceful exit under sibling-suite load.
  async onApplicationShutdown(): Promise<void> {
    await db.close();
  }
}
