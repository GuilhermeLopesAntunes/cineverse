import { db } from '../../prisma/db';
import { SeatMapService } from './seat-map.service';

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        Seat: { where: jest.fn() },
      },
    },
  },
}));

describe('SeatMapService', () => {
  let service: SeatMapService;
  let partnerGateway: {
    getSeatMap: jest.Mock;
    lockSeat: jest.Mock;
    releaseSeat: jest.Mock;
    confirmSale: jest.Mock;
  };
  let seatLockService: { getLockedSeatIds: jest.Mock };
  let seatSelectMock: jest.Mock;
  let seatAllMock: jest.Mock;
  let seatWhereMock: jest.Mock;

  beforeEach(() => {
    partnerGateway = {
      getSeatMap: jest.fn(),
      lockSeat: jest.fn(),
      releaseSeat: jest.fn(),
      confirmSale: jest.fn(),
    };
    seatLockService = {
      getLockedSeatIds: jest.fn().mockResolvedValue(new Set()),
    };
    service = new SeatMapService(partnerGateway, seatLockService as never);

    seatAllMock = jest.fn().mockResolvedValue([]);
    seatSelectMock = jest.fn().mockReturnValue({ all: seatAllMock });
    seatWhereMock = jest.fn().mockReturnValue({ select: seatSelectMock });
    (db.orm.public.Seat.where as jest.Mock) = seatWhereMock;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getMap', () => {
    it('joins the partner status with the seat code', async () => {
      partnerGateway.getSeatMap.mockResolvedValue([
        { seatId: 1, status: 'available' },
        { seatId: 2, status: 'locked' },
      ]);
      seatAllMock.mockResolvedValue([
        { id: 1, code: 'A1' },
        { id: 2, code: 'A2' },
      ]);

      const result = await service.getMap(10);

      expect(partnerGateway.getSeatMap).toHaveBeenCalledWith(10);
      expect(result).toEqual([
        { seatId: 1, code: 'A1', status: 'available' },
        { seatId: 2, code: 'A2', status: 'locked' },
      ]);
    });

    it('skips the Seat query entirely for an empty session', async () => {
      partnerGateway.getSeatMap.mockResolvedValue([]);

      const result = await service.getMap(10);

      expect(result).toEqual([]);
      expect(seatWhereMock).not.toHaveBeenCalled();
    });

    it('falls back to an empty code when a seat somehow has no match', async () => {
      partnerGateway.getSeatMap.mockResolvedValue([
        { seatId: 1, status: 'available' },
      ]);
      seatAllMock.mockResolvedValue([]);

      const result = await service.getMap(10);

      expect(result).toEqual([{ seatId: 1, code: '', status: 'available' }]);
    });

    it('overlays a Redis-held lock as "locked" even if the partner still says available', async () => {
      partnerGateway.getSeatMap.mockResolvedValue([
        { seatId: 1, status: 'available' },
      ]);
      seatAllMock.mockResolvedValue([{ id: 1, code: 'A1' }]);
      seatLockService.getLockedSeatIds.mockResolvedValue(new Set([1]));

      const result = await service.getMap(10);

      expect(result).toEqual([{ seatId: 1, code: 'A1', status: 'locked' }]);
    });

    it('never overrides a "sold" partner status with the Redis overlay', async () => {
      partnerGateway.getSeatMap.mockResolvedValue([
        { seatId: 1, status: 'sold' },
      ]);
      seatAllMock.mockResolvedValue([{ id: 1, code: 'A1' }]);
      seatLockService.getLockedSeatIds.mockResolvedValue(new Set([1]));

      const result = await service.getMap(10);

      expect(result).toEqual([{ seatId: 1, code: 'A1', status: 'sold' }]);
    });
  });

  it('boxOfficeSale delegates to confirmSale with the order id', async () => {
    partnerGateway.confirmSale.mockResolvedValue({ success: true });

    const result = await service.boxOfficeSale(10, 1, 999);

    expect(partnerGateway.confirmSale).toHaveBeenCalledWith(10, 1, 999);
    expect(result).toEqual({ success: true });
  });
});
