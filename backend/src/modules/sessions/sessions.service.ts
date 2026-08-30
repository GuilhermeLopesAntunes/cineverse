import { Injectable, NotFoundException } from '@nestjs/common';
import { db } from '../../prisma/db';
import { CreateSessionDto } from './dto/create-session.dto';
import { PartnersService } from './partners.service';
import { RoomsService } from './rooms.service';

export interface SessionResponse {
  id: number;
  movieId: number;
  roomId: number;
  datetime: string;
  priceCents: number;
}

export interface NearbySessionsResult {
  partner: { id: number; name: string; distanceKm: number };
  sessions: SessionResponse[];
}

const SESSION_FIELDS = [
  'id',
  'movieId',
  'roomId',
  'datetime',
  'priceCents',
] as const;

@Injectable()
export class SessionsService {
  constructor(
    private readonly roomsService: RoomsService,
    private readonly partnersService: PartnersService,
  ) {}

  async create(dto: CreateSessionDto): Promise<SessionResponse> {
    await this.roomsService.findOrThrow(dto.roomId);

    const movie = await db.orm.public.Movie.where({ id: dto.movieId }).first();
    if (!movie) {
      throw new NotFoundException(`Filme ${dto.movieId} não encontrado`);
    }

    return db.orm.public.Session.select(...SESSION_FIELDS).create({
      movieId: dto.movieId,
      roomId: dto.roomId,
      datetime: dto.datetime,
      priceCents: dto.priceCents,
    });
  }

  async list(roomId?: number): Promise<SessionResponse[]> {
    const collection = roomId
      ? db.orm.public.Session.where({ roomId })
      : db.orm.public.Session;

    return collection
      .select(...SESSION_FIELDS)
      .orderBy((s) => s.datetime.asc())
      .all();
  }

  // RF-07: sessions at the nearest cinema partner to the given coordinates.
  // MVP has one partner, so this always resolves to it — but the distance
  // math and the "no partner registered yet" case are real regardless.
  async findNearby(lat: number, lng: number): Promise<NearbySessionsResult> {
    const nearest = await this.partnersService.findNearest(lat, lng);
    if (!nearest) {
      throw new NotFoundException('Nenhum cinema parceiro cadastrado');
    }

    const rooms = await this.roomsService.listByPartner(nearest.partner.id);
    const roomIds = rooms.map((room) => room.id);

    const sessions =
      roomIds.length === 0
        ? []
        : await db.orm.public.Session.where((s) => s.roomId.in(roomIds))
            .where((s) => s.datetime.gte(new Date().toISOString()))
            .select(...SESSION_FIELDS)
            .orderBy((s) => s.datetime.asc())
            .all();

    return {
      partner: {
        id: nearest.partner.id,
        name: nearest.partner.name,
        distanceKm: nearest.distanceKm,
      },
      sessions,
    };
  }
}
