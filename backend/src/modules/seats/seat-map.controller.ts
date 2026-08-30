import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { AuthenticatedUser } from '../../common/guards/jwt-auth.guard';
import type { PartnerConfirmSaleResult } from '../partner-integration/partner-ticketing-gateway.interface';
import { BoxOfficeSaleDto } from './dto/box-office-sale.dto';
import { LockSeatsDto } from './dto/lock-seats.dto';
import { SeatMapEntry, SeatMapService } from './seat-map.service';
import { SeatLockResult, SeatLockService } from './seat-lock.service';
import { SeatsGateway } from './seats.gateway';

@Controller('sessions/:sessionId/seats')
export class SeatMapController {
  constructor(
    private readonly seatMapService: SeatMapService,
    private readonly seatLockService: SeatLockService,
    private readonly seatsGateway: SeatsGateway,
  ) {}

  @Get('map')
  getMap(
    @Param('sessionId', ParseIntPipe) sessionId: number,
  ): Promise<SeatMapEntry[]> {
    return this.seatMapService.getMap(sessionId);
  }

  // The group, all-or-nothing lock (RNF-08/BE-23) — this is what checkout
  // (BE-24/25) will actually call for "reserve every seat the customer
  // selected." A REST action, not WS: the caller needs one definitive
  // accept/reject for the whole batch, not a stream of per-seat events.
  @Post('lock')
  async lockSeats(
    @Param('sessionId', ParseIntPipe) sessionId: number,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: LockSeatsDto,
  ): Promise<SeatLockResult> {
    const result = await this.seatLockService.lockSeats(
      sessionId,
      dto.seatIds,
      user.userId,
    );
    if (result.success) {
      dto.seatIds.forEach((seatId) =>
        this.seatsGateway.broadcastSeatLocked(sessionId, seatId),
      );
    }
    return result;
  }

  @Post('release')
  async releaseSeats(
    @Param('sessionId', ParseIntPipe) sessionId: number,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: LockSeatsDto,
  ): Promise<{ releasedSeatIds: number[] }> {
    const releasedSeatIds = await this.seatLockService.releaseSeats(
      sessionId,
      dto.seatIds,
      user.userId,
    );
    releasedSeatIds.forEach((seatId) =>
      this.seatsGateway.broadcastSeatReleased(sessionId, seatId),
    );
    return { releasedSeatIds };
  }

  // Simulates a sale made at the physical box office — outside the app,
  // outside any WebSocket client. Exists so BE-22's own acceptance
  // criterion ("assento vendido no balcão físico desaparece do app em
  // tempo real") has something to actually trigger; there's no real
  // checkout flow yet (BE-24/25) to drive this the normal way.
  @Post(':seatId/box-office-sale')
  async boxOfficeSale(
    @Param('sessionId', ParseIntPipe) sessionId: number,
    @Param('seatId', ParseIntPipe) seatId: number,
    @Body() dto: BoxOfficeSaleDto,
  ): Promise<PartnerConfirmSaleResult> {
    const result = await this.seatMapService.boxOfficeSale(
      sessionId,
      seatId,
      dto.orderId,
    );
    if (result.success) {
      this.seatsGateway.broadcastSeatSold(sessionId, seatId);
    }
    return result;
  }
}
