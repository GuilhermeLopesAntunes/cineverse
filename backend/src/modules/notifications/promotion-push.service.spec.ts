import { db } from '../../prisma/db';
import { PromotionPushService } from './promotion-push.service';

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        PushToken: {},
      },
    },
  },
}));

describe('PromotionPushService', () => {
  let service: PromotionPushService;
  let pushSender: { send: jest.Mock };
  let selectMock: jest.Mock;
  let allMock: jest.Mock;

  beforeEach(() => {
    pushSender = { send: jest.fn().mockResolvedValue({ success: true }) };
    service = new PromotionPushService(pushSender);

    allMock = jest.fn().mockResolvedValue([]);
    selectMock = jest.fn().mockReturnValue({ all: allMock });
    (db.orm.public.PushToken as unknown as { select: jest.Mock }).select =
      selectMock;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('broadcast', () => {
    it('sends the promotion to every registered device and reports how many', async () => {
      allMock.mockResolvedValue([
        { token: 'device-a' },
        { token: 'device-b' },
        { token: 'device-c' },
      ]);

      const result = await service.broadcast({
        title: 'Promoção',
        body: 'Pipoca grátis hoje!',
      });

      expect(pushSender.send).toHaveBeenCalledTimes(3);
      expect(pushSender.send).toHaveBeenCalledWith(
        'device-a',
        'Promoção',
        'Pipoca grátis hoje!',
      );
      expect(pushSender.send).toHaveBeenCalledWith(
        'device-b',
        'Promoção',
        'Pipoca grátis hoje!',
      );
      expect(pushSender.send).toHaveBeenCalledWith(
        'device-c',
        'Promoção',
        'Pipoca grátis hoje!',
      );
      expect(result).toEqual({ sentTo: 3 });
    });

    it('reports zero and sends nothing when no device is registered', async () => {
      allMock.mockResolvedValue([]);

      const result = await service.broadcast({
        title: 'Promoção',
        body: 'Ninguém vai ver isso',
      });

      expect(pushSender.send).not.toHaveBeenCalled();
      expect(result).toEqual({ sentTo: 0 });
    });
  });
});
