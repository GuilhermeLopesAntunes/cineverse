import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { BroadcastPromotionDto } from './dto/broadcast-promotion.dto';
import {
  BroadcastResult,
  PromotionPushService,
} from './promotion-push.service';

@Controller('notifications')
export class PromotionPushController {
  constructor(private readonly promotionPushService: PromotionPushService) {}

  // No @Public(), no dedicated staff/marketing role — same MVP
  // simplification as the rest of this app (box-office-sale, ticket
  // validation): standard JWT guard is all that gates it.
  @Post('broadcast')
  @HttpCode(HttpStatus.OK)
  broadcast(@Body() dto: BroadcastPromotionDto): Promise<BroadcastResult> {
    return this.promotionPushService.broadcast(dto);
  }
}
