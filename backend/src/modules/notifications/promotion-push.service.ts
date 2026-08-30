import { Inject, Injectable, Logger } from '@nestjs/common';
import { db } from '../../prisma/db';
import { BroadcastPromotionDto } from './dto/broadcast-promotion.dto';
import { PUSH_SENDER } from './push-sender.interface';
import type { PushSender } from './push-sender.interface';

export interface BroadcastResult {
  sentTo: number;
}

// RF-17's other push flavor: unlike SessionReminderService (BE-35, one
// notification per user/session, driven by purchase data), this is a
// one-off broadcast to every registered device — there's no targeting or
// opt-in preference in this app yet, so "promoções/novidades" means
// literally every `PushToken` on file. No admin/staff role exists either
// (same MVP simplification as the rest of this app), so any authenticated
// caller can trigger one (see PromotionPushController).
@Injectable()
export class PromotionPushService {
  private readonly logger = new Logger(PromotionPushService.name);

  constructor(@Inject(PUSH_SENDER) private readonly pushSender: PushSender) {}

  async broadcast(dto: BroadcastPromotionDto): Promise<BroadcastResult> {
    const tokens = await db.orm.public.PushToken.select('token').all();

    await Promise.all(
      tokens.map((t) => this.pushSender.send(t.token, dto.title, dto.body)),
    );

    this.logger.log(`Promotion broadcast sent to ${tokens.length} device(s)`);
    return { sentTo: tokens.length };
  }
}
