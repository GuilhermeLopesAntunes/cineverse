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
import { JoinSessionDto } from './dto/join-session.dto';
import { SeatActionDto } from './dto/seat-action.dto';
import { SeatLockService } from './seat-lock.service';

export function sessionRoom(sessionId: number): string {
  return `session:${sessionId}`;
}

const VALIDATION_PIPE = new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
});

// No membership concept like ChatGateway's rooms — any authenticated user
// can watch any session's seat map (same as GET /catalog/movies, there's no
// per-session access control anywhere else in the app either) and the
// handshake auth (BE-18) already guarantees "authenticated", which is all
// this needs.
@UseFilters(WsHttpExceptionFilter)
@WebSocketGateway({ namespace: '/seats' })
export class SeatsGateway {
  @WebSocketServer()
  server!: Server;

  constructor(private readonly seatLockService: SeatLockService) {}

  @UsePipes(VALIDATION_PIPE)
  @SubscribeMessage('joinSession')
  async handleJoinSession(
    @ConnectedSocket() socket: AuthenticatedSocket,
    @MessageBody() dto: JoinSessionDto,
  ): Promise<void> {
    await socket.join(sessionRoom(dto.sessionId));
  }

  // Single-seat "quick tap" hold — under the hood this is exactly
  // SeatLockService's atomic group lock with a group of one (BE-23). The
  // REST group-lock endpoint (SeatMapController) is the one checkout will
  // actually use for "reserve all N selected seats" (RF-09).
  @UsePipes(VALIDATION_PIPE)
  @SubscribeMessage('lockSeat')
  async handleLockSeat(
    @ConnectedSocket() socket: AuthenticatedSocket,
    @MessageBody() dto: SeatActionDto,
  ): Promise<void> {
    const result = await this.seatLockService.lockSeats(
      dto.sessionId,
      [dto.seatId],
      socket.data.user.userId,
    );
    await socket.join(sessionRoom(dto.sessionId));

    if (result.success) {
      this.server
        .to(sessionRoom(dto.sessionId))
        .emit('seat_locked', { sessionId: dto.sessionId, seatId: dto.seatId });
    } else {
      // Losing a race for a seat is routine, not an error — told only to
      // the caller, not broadcast (nobody else's view actually changed).
      socket.emit('lockRejected', {
        sessionId: dto.sessionId,
        seatId: dto.seatId,
        reason: result.reason,
      });
    }
  }

  @UsePipes(VALIDATION_PIPE)
  @SubscribeMessage('releaseSeat')
  async handleReleaseSeat(
    @ConnectedSocket() socket: AuthenticatedSocket,
    @MessageBody() dto: SeatActionDto,
  ): Promise<void> {
    const released = await this.seatLockService.releaseSeats(
      dto.sessionId,
      [dto.seatId],
      socket.data.user.userId,
    );
    await socket.join(sessionRoom(dto.sessionId));
    // Nothing to tell anyone if this caller never actually held the seat —
    // no state changed, so no broadcast (same "don't lie about what
    // changed" reasoning as lockSeat's lockRejected path).
    if (released.length > 0) {
      this.server.to(sessionRoom(dto.sessionId)).emit('seat_released', {
        sessionId: dto.sessionId,
        seatId: dto.seatId,
      });
    }
  }

  // Called by SeatMapController (REST) for both the group lock/release
  // endpoints and the box-office sale simulation — none of those have a
  // socket in the loop (box-office sale has none at all; the REST group
  // actions have an HTTP caller, not a connected socket), so there's
  // nothing to broadcast *to* except this shared room directly.
  broadcastSeatLocked(sessionId: number, seatId: number): void {
    this.server
      .to(sessionRoom(sessionId))
      .emit('seat_locked', { sessionId, seatId });
  }

  broadcastSeatReleased(sessionId: number, seatId: number): void {
    this.server
      .to(sessionRoom(sessionId))
      .emit('seat_released', { sessionId, seatId });
  }

  broadcastSeatSold(sessionId: number, seatId: number): void {
    this.server
      .to(sessionRoom(sessionId))
      .emit('seat_sold', { sessionId, seatId });
  }
}
