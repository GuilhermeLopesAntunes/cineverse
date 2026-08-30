import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseIntPipe,
  Post,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import type { AuthenticatedUser } from '../../common/guards/jwt-auth.guard';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { PixWebhookDto } from './dto/pix-webhook.dto';
import { PaymentResponse, PaymentsService } from './payments.service';

@Controller()
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Post('orders/:orderId/payments')
  @HttpCode(HttpStatus.CREATED)
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Param('orderId', ParseIntPipe) orderId: number,
    @Body() dto: CreatePaymentDto,
  ): Promise<PaymentResponse & { copyPasteCode?: string }> {
    return this.paymentsService.create(user.userId, orderId, dto);
  }

  @Get('orders/:orderId/payments')
  list(
    @CurrentUser() user: AuthenticatedUser,
    @Param('orderId', ParseIntPipe) orderId: number,
  ): Promise<PaymentResponse[]> {
    return this.paymentsService.listByOrder(user.userId, orderId);
  }

  // Called by the (mocked) Pix provider, not a logged-in client — no user
  // JWT to check, hence @Public().
  @Public()
  @Post('payments/webhook/pix')
  @HttpCode(HttpStatus.OK)
  async handlePixWebhook(@Body() dto: PixWebhookDto): Promise<{ ok: true }> {
    await this.paymentsService.handlePixWebhook(dto);
    return { ok: true };
  }
}
