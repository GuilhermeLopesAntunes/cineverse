import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { isUniqueViolation } from '../../common/prisma/is-unique-violation';
import { db } from '../../prisma/db';
import { CreateSeatsDto } from './dto/create-seats.dto';

export interface SeatResponse {
  id: number;
  roomId: number;
  code: string;
}

@Injectable()
export class SeatsService {
  async createMany(
    roomId: number,
    dto: CreateSeatsDto,
  ): Promise<SeatResponse[]> {
    await this.findRoomOrThrow(roomId);

    try {
      // One transaction: either every seat in the batch lands, or none do —
      // a half-created room (e.g. rows A-C in but D failed on a duplicate
      // code) is worse than just retrying the whole batch.
      return await db.transaction(async (tx) => {
        const created: SeatResponse[] = [];
        for (const code of dto.codes) {
          const seat = await tx.orm.public.Seat.select(
            'id',
            'roomId',
            'code',
          ).create({
            roomId,
            code,
          });
          created.push(seat);
        }
        return created;
      });
    } catch (err) {
      if (isUniqueViolation(err)) {
        throw new ConflictException(
          'Um ou mais códigos de assento já existem nessa sala',
        );
      }
      throw err;
    }
  }

  async listByRoom(roomId: number): Promise<SeatResponse[]> {
    await this.findRoomOrThrow(roomId);
    return db.orm.public.Seat.where({ roomId })
      .select('id', 'roomId', 'code')
      .orderBy((s) => s.code.asc())
      .all();
  }

  private async findRoomOrThrow(roomId: number): Promise<void> {
    const room = await db.orm.public.Room.where({ id: roomId }).first();
    if (!room) {
      throw new NotFoundException(`Sala ${roomId} não encontrada`);
    }
  }
}
