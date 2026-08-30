import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import type { Queue } from 'bullmq';
import { sessionReminderConfig } from './session-reminder.config';
import {
  SESSION_REMINDER_JOB,
  SESSION_REMINDER_QUEUE,
  SESSION_REMINDER_SCHEDULER_ID,
} from './session-reminder.constants';

// Registers the recurring schedule once at boot. `upsertJobScheduler` is
// idempotent by its id — re-registering the same schedule on every app
// restart updates it in place rather than piling up duplicates.
@Injectable()
export class SessionReminderScheduler implements OnModuleInit {
  private readonly logger = new Logger(SessionReminderScheduler.name);

  constructor(
    @InjectQueue(SESSION_REMINDER_QUEUE) private readonly queue: Queue,
  ) {}

  async onModuleInit(): Promise<void> {
    const intervalMs = sessionReminderConfig.intervalMs;
    const jobOptions = {
      attempts: 2,
      removeOnComplete: true,
      removeOnFail: 50,
    };

    await this.queue.upsertJobScheduler(
      SESSION_REMINDER_SCHEDULER_ID,
      { every: intervalMs },
      { name: SESSION_REMINDER_JOB, opts: jobOptions },
    );

    // The scheduler's own first run is delayed by `intervalMs` — fire one
    // immediately too, so a session inside the reminder window at boot
    // doesn't have to wait a full tick to be picked up.
    await this.queue.add(SESSION_REMINDER_JOB, {}, jobOptions);

    this.logger.log(`Session reminder job scheduled every ${intervalMs}ms`);
  }
}
