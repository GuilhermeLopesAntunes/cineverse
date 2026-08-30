import { Inject, Injectable, Logger } from '@nestjs/common';
import { isUniqueViolation } from '../../common/prisma/is-unique-violation';
import { db } from '../../prisma/db';
import { sessionReminderConfig } from './session-reminder.config';
import { PUSH_SENDER } from './push-sender.interface';
import type { PushSender } from './push-sender.interface';

export interface SessionReminderRunResult {
  remindersSent: number;
}

// RF-17: "usuário recebe notificação antes do horário da sessão comprada."
// Runs on a recurring job tick (SessionReminderScheduler/Processor) rather
// than being scheduled per-purchase — simpler, and naturally survives app
// restarts/deploys without needing a durable per-order timer. Exactly one
// reminder per (user, session), never per seat/order: someone who bought 3
// seats for the same session gets notified once, not 3 times.
@Injectable()
export class SessionReminderService {
  private readonly logger = new Logger(SessionReminderService.name);

  constructor(@Inject(PUSH_SENDER) private readonly pushSender: PushSender) {}

  async sendDueReminders(): Promise<SessionReminderRunResult> {
    const now = new Date();
    const windowEnd = new Date(
      now.getTime() + sessionReminderConfig.hoursBefore * 60 * 60 * 1000,
    );

    const dueSessions = await db.orm.public.Session.where((s) =>
      s.datetime.gte(now.toISOString()),
    )
      .where((s) => s.datetime.lte(windowEnd.toISOString()))
      .select('id', 'datetime')
      .all();
    if (dueSessions.length === 0) {
      return { remindersSent: 0 };
    }
    const sessionIds = dueSessions.map((s) => s.id);
    const datetimeBySession = new Map(
      dueSessions.map((s) => [s.id, s.datetime]),
    );

    const paidOrders = await db.orm.public.Order.where((o) =>
      o.sessionId.in(sessionIds),
    )
      .where({ status: 'paid' })
      .select('userId', 'sessionId')
      .all();
    if (paidOrders.length === 0) {
      return { remindersSent: 0 };
    }

    // De-dupe to one (user, session) pair regardless of how many paid
    // orders that user has for it.
    const duePairs = new Map<string, { userId: number; sessionId: number }>();
    for (const order of paidOrders) {
      duePairs.set(`${order.userId}:${order.sessionId}`, order);
    }

    const alreadySent = await db.orm.public.SessionReminder.where((r) =>
      r.sessionId.in(sessionIds),
    )
      .select('userId', 'sessionId')
      .all();
    const alreadySentKeys = new Set(
      alreadySent.map((r) => `${r.userId}:${r.sessionId}`),
    );

    const userIds = [...new Set([...duePairs.values()].map((p) => p.userId))];
    const pushTokens = await db.orm.public.PushToken.where((t) =>
      t.userId.in(userIds),
    )
      .select('userId', 'token')
      .all();
    const tokensByUser = new Map<number, string[]>();
    for (const pt of pushTokens) {
      const tokens = tokensByUser.get(pt.userId) ?? [];
      tokens.push(pt.token);
      tokensByUser.set(pt.userId, tokens);
    }

    let remindersSent = 0;
    for (const [key, { userId, sessionId }] of duePairs) {
      if (alreadySentKeys.has(key)) {
        continue;
      }

      const datetime = datetimeBySession.get(sessionId);
      const tokens = tokensByUser.get(userId) ?? [];
      await Promise.all(
        tokens.map((token) =>
          this.pushSender.send(
            token,
            'Sua sessão está chegando',
            `Sua sessão começa em ${datetime} — não esqueça!`,
          ),
        ),
      );

      try {
        await db.orm.public.SessionReminder.create({ userId, sessionId });
        remindersSent++;
      } catch (err) {
        // Lost a race with another tick of this same job for this exact
        // pair — already recorded, not an error.
        if (!isUniqueViolation(err)) {
          throw err;
        }
      }
    }

    this.logger.log(`Session reminders sent: ${remindersSent}`);
    return { remindersSent };
  }
}
