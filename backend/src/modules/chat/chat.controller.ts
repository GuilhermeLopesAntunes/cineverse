import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { AuthenticatedUser } from '../../common/guards/jwt-auth.guard';
import {
  ChatRoomResponse,
  ChatService,
  MessageResponse,
  Paginated,
} from './chat.service';
import { CreateChatRoomDto } from './dto/create-chat-room.dto';
import { PaginationQueryDto } from './dto/pagination-query.dto';

@Controller('chat/rooms')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Post()
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateChatRoomDto,
  ): Promise<ChatRoomResponse> {
    return this.chatService.createRoom(user.userId, dto);
  }

  @Get()
  list(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: PaginationQueryDto,
  ): Promise<Paginated<ChatRoomResponse>> {
    return this.chatService.listRooms(user.userId, query.page, query.pageSize);
  }

  @Get(':roomId/messages')
  listMessages(
    @CurrentUser() user: AuthenticatedUser,
    @Param('roomId', ParseIntPipe) roomId: number,
    @Query() query: PaginationQueryDto,
  ): Promise<Paginated<MessageResponse>> {
    return this.chatService.listMessages(
      roomId,
      user.userId,
      query.page,
      query.pageSize,
    );
  }
}
