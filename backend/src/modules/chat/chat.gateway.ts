import { UseFilters, UsePipes, ValidationPipe } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Server } from 'socket.io';
import type { AuthenticatedSocket } from '../../websocket/ws-auth.middleware';
import { WsHttpExceptionFilter } from '../../websocket/ws-http-exception.filter';
import { ChatService } from './chat.service';
import { JoinRoomDto } from './dto/join-room.dto';
import { SendMessageDto } from './dto/send-message.dto';

function roomName(roomId: number): string {
  return `room:${roomId}`;
}

// Handshake auth (JWT → socket.data.user) is already done for every
// namespace by the adapter itself (BE-18, src/websocket/redis-io.adapter.ts)
// — this gateway only has to check *room* membership, not identity.
@UseFilters(WsHttpExceptionFilter)
@WebSocketGateway({ namespace: '/chat' })
export class ChatGateway {
  @WebSocketServer()
  server!: Server;

  constructor(private readonly chatService: ChatService) {}

  @UsePipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  )
  @SubscribeMessage('joinRoom')
  async handleJoinRoom(
    @ConnectedSocket() socket: AuthenticatedSocket,
    @MessageBody() dto: JoinRoomDto,
  ): Promise<void> {
    await this.chatService.assertMember(dto.roomId, socket.data.user.userId);
    await socket.join(roomName(dto.roomId));
  }

  // Joins the room defensively (idempotent) so the sender's own socket is
  // guaranteed to be in the broadcast, even if it never called `joinRoom` —
  // e.g. sending a message from a fresh reconnect.
  @UsePipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  )
  @SubscribeMessage('sendMessage')
  async handleSendMessage(
    @ConnectedSocket() socket: AuthenticatedSocket,
    @MessageBody() dto: SendMessageDto,
  ): Promise<void> {
    const senderId = socket.data.user.userId;
    const message = await this.chatService.createMessage(
      dto.roomId,
      senderId,
      dto.content,
    );
    await socket.join(roomName(dto.roomId));
    this.server.to(roomName(dto.roomId)).emit('newMessage', message);
  }
}
