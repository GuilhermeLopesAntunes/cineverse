import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Query,
} from '@nestjs/common';
import { CreateSessionDto } from './dto/create-session.dto';
import { ListSessionsQueryDto } from './dto/list-sessions-query.dto';
import { NearbySessionsQueryDto } from './dto/nearby-sessions-query.dto';
import {
  NearbySessionsResult,
  SessionResponse,
  SessionsService,
} from './sessions.service';

@Controller('sessions')
export class SessionsController {
  constructor(private readonly sessionsService: SessionsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@Body() dto: CreateSessionDto): Promise<SessionResponse> {
    return this.sessionsService.create(dto);
  }

  @Get()
  list(@Query() query: ListSessionsQueryDto): Promise<SessionResponse[]> {
    return this.sessionsService.list(query.roomId);
  }

  // Static segment, no route-order ambiguity with the plain GET / above —
  // there's no GET /sessions/:id today, so nothing else could match "nearby".
  @Get('nearby')
  findNearby(
    @Query() query: NearbySessionsQueryDto,
  ): Promise<NearbySessionsResult> {
    return this.sessionsService.findNearby(query.lat, query.lng);
  }
}
