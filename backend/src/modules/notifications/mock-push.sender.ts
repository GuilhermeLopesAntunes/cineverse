import { Injectable, Logger } from '@nestjs/common';
import type { PushSendResult, PushSender } from './push-sender.interface';

// Simulates FCM delivery — always succeeds, since there's no real Firebase
// project to send against yet. Logs instead of actually reaching a device,
// which is also what makes this observable/testable live without a real
// phone in hand.
@Injectable()
export class MockPushSender implements PushSender {
  private readonly logger = new Logger(MockPushSender.name);

  send(token: string, title: string, body: string): Promise<PushSendResult> {
    this.logger.log(`[mock push -> ${token}] ${title}: ${body}`);
    return Promise.resolve({ success: true });
  }
}
