import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { MockPushSender } from './mock-push.sender';
import { PromotionPushController } from './promotion-push.controller';
import { PromotionPushService } from './promotion-push.service';
import { PUSH_SENDER } from './push-sender.interface';
import { PushTokensController } from './push-tokens.controller';
import { PushTokensService } from './push-tokens.service';
import { SESSION_REMINDER_QUEUE } from './session-reminder.constants';
import { SessionReminderProcessor } from './session-reminder.processor';
import { SessionReminderScheduler } from './session-reminder.scheduler';
import { SessionReminderService } from './session-reminder.service';

@Module({
  imports: [BullModule.registerQueue({ name: SESSION_REMINDER_QUEUE })],
  controllers: [PushTokensController, PromotionPushController],
  providers: [
    PushTokensService,
    { provide: PUSH_SENDER, useClass: MockPushSender },
    SessionReminderService,
    SessionReminderProcessor,
    SessionReminderScheduler,
    PromotionPushService,
  ],
})
export class NotificationsModule {}
