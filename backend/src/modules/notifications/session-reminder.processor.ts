import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import type { Job } from 'bullmq';
import { SessionReminderService } from './session-reminder.service';
import {
  SESSION_REMINDER_JOB,
  SESSION_REMINDER_QUEUE,
} from './session-reminder.constants';

@Processor(SESSION_REMINDER_QUEUE)
export class SessionReminderProcessor extends WorkerHost {
  private readonly logger = new Logger(SessionReminderProcessor.name);

  constructor(private readonly sessionReminderService: SessionReminderService) {
    super();
  }

  async process(job: Job): Promise<void> {
    if (job.name !== SESSION_REMINDER_JOB) {
      throw new Error(
        `Unknown job "${job.name}" on queue "${SESSION_REMINDER_QUEUE}"`,
      );
    }

    try {
      await this.sessionReminderService.sendDueReminders();
    } catch (err) {
      this.logger.error(
        `Session reminder run failed: ${err instanceof Error ? err.message : String(err)}`,
      );
      throw err;
    }
  }
}
