import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  NotFoundException,
  Put,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { AuthenticatedUser } from '../../common/guards/jwt-auth.guard';
import { UpsertProfileDto } from './dto/upsert-profile.dto';
import { UserProfileResponse, UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me/profile')
  async getMyProfile(
    @CurrentUser() user: AuthenticatedUser,
  ): Promise<UserProfileResponse> {
    const profile = await this.usersService.getProfile(user.userId);
    if (!profile) {
      throw new NotFoundException('Perfil ainda não configurado');
    }
    return profile;
  }

  @Put('me/profile')
  @HttpCode(HttpStatus.OK)
  upsertMyProfile(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpsertProfileDto,
  ): Promise<UserProfileResponse> {
    return this.usersService.upsertProfile(user.userId, dto);
  }
}
