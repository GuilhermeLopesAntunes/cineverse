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
import { CreateSeatsDto } from './dto/create-seats.dto';
import { SeatResponse, SeatsService } from './seats.service';

@Controller('rooms/:roomId/seats')
export class SeatsController {
  constructor(private readonly seatsService: SeatsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(
    @Param('roomId', ParseIntPipe) roomId: number,
    @Body() dto: CreateSeatsDto,
  ): Promise<SeatResponse[]> {
    return this.seatsService.createMany(roomId, dto);
  }

  @Get()
  list(@Param('roomId', ParseIntPipe) roomId: number): Promise<SeatResponse[]> {
    return this.seatsService.listByRoom(roomId);
  }
}
