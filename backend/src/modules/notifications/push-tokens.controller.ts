import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { AuthenticatedUser } from '../../common/guards/jwt-auth.guard';
import { RegisterPushTokenDto } from './dto/register-push-token.dto';
import { PushTokenResponse, PushTokensService } from './push-tokens.service';

@Controller('push-tokens')
export class PushTokensController {
  constructor(private readonly pushTokensService: PushTokensService) {}

  // 200, not 201 — this can just as well update an already-registered
  // token's owner/platform as create a brand-new row.
  @Post()
  @HttpCode(HttpStatus.OK)
  register(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: RegisterPushTokenDto,
  ): Promise<PushTokenResponse> {
    return this.pushTokensService.register(user.userId, dto);
  }
}
