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
import { CreateRoomDto } from './dto/create-room.dto';
import { RoomResponse, RoomsService } from './rooms.service';

@Controller('partners/:partnerId/rooms')
export class RoomsController {
  constructor(private readonly roomsService: RoomsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(
    @Param('partnerId', ParseIntPipe) partnerId: number,
    @Body() dto: CreateRoomDto,
  ): Promise<RoomResponse> {
    return this.roomsService.create(partnerId, dto);
  }

  @Get()
  list(
    @Param('partnerId', ParseIntPipe) partnerId: number,
  ): Promise<RoomResponse[]> {
    return this.roomsService.listByPartner(partnerId);
  }
}
