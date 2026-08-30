import { db } from '../../prisma/db';
import { SessionReminderService } from './session-reminder.service';

interface Chain {
  where: jest.Mock;
  select: jest.Mock;
  all: jest.Mock;
}

function makeChain(): Chain {
  const chain = {} as Chain;
  chain.where = jest.fn().mockReturnValue(chain);
  chain.select = jest.fn().mockReturnValue(chain);
  chain.all = jest.fn().mockResolvedValue([]);
  return chain;
}

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        Session: {},
        Order: {},
        SessionReminder: {},
        PushToken: {},
      },
    },
  },
}));

describe('SessionReminderService', () => {
  let service: SessionReminderService;
  let pushSender: { send: jest.Mock };
  let sessionChain: Chain;
  let orderChain: Chain;
  let reminderChain: Chain;
  let pushTokenChain: Chain;
  let reminderCreateMock: jest.Mock;

  beforeEach(() => {
    pushSender = { send: jest.fn().mockResolvedValue({ success: true }) };
    service = new SessionReminderService(pushSender);

    sessionChain = makeChain();
    orderChain = makeChain();
    reminderChain = makeChain();
    pushTokenChain = makeChain();

    (db.orm.public.Session as unknown as { where: jest.Mock }).where = jest
      .fn()
      .mockReturnValue(sessionChain);
    (db.orm.public.Order as unknown as { where: jest.Mock }).where = jest
      .fn()
      .mockReturnValue(orderChain);
    (db.orm.public.SessionReminder as unknown as { where: jest.Mock }).where =
      jest.fn().mockReturnValue(reminderChain);
    (db.orm.public.PushToken as unknown as { where: jest.Mock }).where = jest
      .fn()
      .mockReturnValue(pushTokenChain);

    reminderCreateMock = jest.fn().mockResolvedValue({ id: 1 });
    (db.orm.public.SessionReminder as unknown as { create: jest.Mock }).create =
      reminderCreateMock;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('sendDueReminders', () => {
    it('does nothing when no session falls inside the reminder window', async () => {
      sessionChain.all.mockResolvedValue([]);

      const result = await service.sendDueReminders();

      expect(result).toEqual({ remindersSent: 0 });
      expect(pushSender.send).not.toHaveBeenCalled();
    });

    it('does nothing when a due session has no paid order at all', async () => {
      sessionChain.all.mockResolvedValue([
        { id: 1, datetime: '2026-09-01T20:00:00Z' },
      ]);
      orderChain.all.mockResolvedValue([]);

      const result = await service.sendDueReminders();

      expect(result).toEqual({ remindersSent: 0 });
      expect(pushSender.send).not.toHaveBeenCalled();
    });

    it('sends one push per registered device and records the reminder, once per (user, session)', async () => {
      sessionChain.all.mockResolvedValue([
        { id: 1, datetime: '2026-09-01T20:00:00Z' },
      ]);
      // Same user, two seats/orders for the same session — must still only
      // notify (and record) once.
      orderChain.all.mockResolvedValue([
        { userId: 42, sessionId: 1 },
        { userId: 42, sessionId: 1 },
      ]);
      reminderChain.all.mockResolvedValue([]); // nothing sent yet
      pushTokenChain.all.mockResolvedValue([
        { userId: 42, token: 'device-a' },
        { userId: 42, token: 'device-b' },
      ]);

      const result = await service.sendDueReminders();

      expect(pushSender.send).toHaveBeenCalledTimes(2);
      expect(pushSender.send).toHaveBeenCalledWith(
        'device-a',
        expect.any(String),
        expect.stringContaining('2026-09-01T20:00:00Z'),
      );
      expect(pushSender.send).toHaveBeenCalledWith(
        'device-b',
        expect.any(String),
        expect.stringContaining('2026-09-01T20:00:00Z'),
      );
      expect(reminderCreateMock).toHaveBeenCalledTimes(1);
      expect(reminderCreateMock).toHaveBeenCalledWith({
        userId: 42,
        sessionId: 1,
      });
      expect(result).toEqual({ remindersSent: 1 });
    });

    it('skips a (user, session) pair that was already reminded', async () => {
      sessionChain.all.mockResolvedValue([
        { id: 1, datetime: '2026-09-01T20:00:00Z' },
      ]);
      orderChain.all.mockResolvedValue([{ userId: 42, sessionId: 1 }]);
      reminderChain.all.mockResolvedValue([{ userId: 42, sessionId: 1 }]);

      const result = await service.sendDueReminders();

      expect(pushSender.send).not.toHaveBeenCalled();
      expect(reminderCreateMock).not.toHaveBeenCalled();
      expect(result).toEqual({ remindersSent: 0 });
    });

    it('a user with no registered device still gets a recorded reminder, just no push sent', async () => {
      sessionChain.all.mockResolvedValue([
        { id: 1, datetime: '2026-09-01T20:00:00Z' },
      ]);
      orderChain.all.mockResolvedValue([{ userId: 42, sessionId: 1 }]);
      reminderChain.all.mockResolvedValue([]);
      pushTokenChain.all.mockResolvedValue([]);

      const result = await service.sendDueReminders();

      expect(pushSender.send).not.toHaveBeenCalled();
      expect(reminderCreateMock).toHaveBeenCalledWith({
        userId: 42,
        sessionId: 1,
      });
      expect(result).toEqual({ remindersSent: 1 });
    });

    it('does not fail the whole run when recording the reminder races another tick of the same job', async () => {
      sessionChain.all.mockResolvedValue([
        { id: 1, datetime: '2026-09-01T20:00:00Z' },
      ]);
      orderChain.all.mockResolvedValue([{ userId: 42, sessionId: 1 }]);
      reminderChain.all.mockResolvedValue([]);
      pushTokenChain.all.mockResolvedValue([{ userId: 42, token: 'device-a' }]);
      reminderCreateMock.mockRejectedValue({ sqlState: '23505' });

      const result = await service.sendDueReminders();

      expect(pushSender.send).toHaveBeenCalledTimes(1);
      expect(result).toEqual({ remindersSent: 0 });
    });
  });
});
