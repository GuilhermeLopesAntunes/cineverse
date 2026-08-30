import { Injectable } from '@nestjs/common';
import { isUniqueViolation } from '../../common/prisma/is-unique-violation';
import { db } from '../../prisma/db';
import { RegisterPushTokenDto } from './dto/register-push-token.dto';

export interface PushTokenResponse {
  id: number;
  userId: number;
  token: string;
  platform: string;
  createdAt: string;
}

const PUSH_TOKEN_FIELDS = [
  'id',
  'userId',
  'token',
  'platform',
  'createdAt',
] as const;

// RF-17: one row per (user, device) — registering a token the app has
// already seen (app restart, re-login) re-points it at the current
// `userId`/`platform` instead of erroring or duplicating it; a token can
// legitimately change owner (a different user logs into the same device).
@Injectable()
export class PushTokensService {
  async register(
    userId: number,
    dto: RegisterPushTokenDto,
  ): Promise<PushTokenResponse> {
    const existing = await db.orm.public.PushToken.where({
      token: dto.token,
    }).first();

    if (existing) {
      await db.orm.public.PushToken.where({ token: dto.token }).update({
        userId,
        platform: dto.platform,
      });
    } else {
      try {
        await db.orm.public.PushToken.create({
          userId,
          token: dto.token,
          platform: dto.platform,
        });
      } catch (err) {
        // Not `.upsert()` — its conflict detection only keys off the
        // model's primary key, not an arbitrary `@unique` field like
        // `token` here (same gotcha CatalogSyncService hit with `tmdbId`).
        // Lost a race with another registration of this same token between
        // the read above and this create — fall through to the update,
        // the row exists now.
        if (!isUniqueViolation(err)) {
          throw err;
        }
        await db.orm.public.PushToken.where({ token: dto.token }).update({
          userId,
          platform: dto.platform,
        });
      }
    }

    const pushToken = await db.orm.public.PushToken.where({
      token: dto.token,
    })
      .select(...PUSH_TOKEN_FIELDS)
      .first();
    return pushToken!;
  }
}
