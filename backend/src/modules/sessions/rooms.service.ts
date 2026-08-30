import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { isUniqueViolation } from '../../common/prisma/is-unique-violation';
import { db } from '../../prisma/db';
import { CreateRoomDto } from './dto/create-room.dto';
import { PartnersService } from './partners.service';

export interface RoomResponse {
  id: number;
  partnerId: number;
  name: string;
}

@Injectable()
export class RoomsService {
  constructor(private readonly partnersService: PartnersService) {}

  async create(partnerId: number, dto: CreateRoomDto): Promise<RoomResponse> {
    await this.partnersService.findOrThrow(partnerId);

    try {
      return await db.orm.public.Room.select('id', 'partnerId', 'name').create({
        partnerId,
        name: dto.name,
      });
    } catch (err) {
      if (isUniqueViolation(err)) {
        throw new ConflictException(
          `Sala "${dto.name}" já existe para esse parceiro`,
        );
      }
      throw err;
    }
  }

  async listByPartner(partnerId: number): Promise<RoomResponse[]> {
    await this.partnersService.findOrThrow(partnerId);
    return db.orm.public.Room.where({ partnerId })
      .select('id', 'partnerId', 'name')
      .orderBy((r) => r.id.asc())
      .all();
  }

  async findOrThrow(id: number): Promise<RoomResponse> {
    const room = await db.orm.public.Room.where({ id })
      .select('id', 'partnerId', 'name')
      .first();
    if (!room) {
      throw new NotFoundException(`Sala ${id} não encontrada`);
    }
    return room;
  }
}
