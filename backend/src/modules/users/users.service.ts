import { Injectable } from '@nestjs/common';
import { db } from '../../prisma/db';
import { UpsertProfileDto } from './dto/upsert-profile.dto';

export interface UserProfileResponse {
  userId: number;
  favoriteGenres: string[];
}

@Injectable()
export class UsersService {
  async getProfile(userId: number): Promise<UserProfileResponse | null> {
    const profile = await db.orm.public.UserProfile.where({ userId }).first();
    if (!profile) {
      return null;
    }
    return { userId, favoriteGenres: await this.listGenres(userId) };
  }

  async upsertProfile(
    userId: number,
    dto: UpsertProfileDto,
  ): Promise<UserProfileResponse> {
    await db.transaction(async (tx) => {
      const existing = await tx.orm.public.UserProfile.where({
        userId,
      }).first();
      if (!existing) {
        await tx.orm.public.UserProfile.create({ userId });
      }

      // Full-replace semantics: the client sends its whole current
      // selection, not a diff. Deliberately the SQL builder, not
      // `db.orm...delete()` — the ORM lane's predicate delete only removes
      // one matching row, not all of them (verified against a real DB: it
      // silently left rows behind on a multi-row match).
      const deletePlan = tx.sql.public.favoriteGenre
        .delete()
        .where((f, fns) => fns.eq(f.userId, userId))
        .build();
      await tx.execute(deletePlan);

      for (const genre of dto.favoriteGenres) {
        await tx.orm.public.FavoriteGenre.create({ userId, genre });
      }
    });

    return { userId, favoriteGenres: dto.favoriteGenres };
  }

  private async listGenres(userId: number): Promise<string[]> {
    const rows = await db.orm.public.FavoriteGenre.where({ userId })
      .select('genre')
      .all();
    return rows.map((row) => row.genre);
  }
}
