import { db } from '../../prisma/db';
import { TicketsService } from './tickets.service';

const sampleTicket = {
  id: 5,
  orderItemId: 7,
  qrCodePayload: 'signed.jwt.token',
  status: 'valid',
  usedAt: null,
  createdAt: 'now',
};

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        Ticket: {},
      },
    },
    sql: {
      public: {
        ticket: {},
      },
    },
    transaction: jest.fn(),
  },
}));

describe('TicketsService', () => {
  let service: TicketsService;
  let jwtService: { signAsync: jest.Mock; verifyAsync: jest.Mock };
  let ticketCreateMock: jest.Mock;
  let ticketFirstMock: jest.Mock;
  let ticketWhereMock: jest.Mock;
  let sqlUpdateMock: jest.Mock;
  let sqlWhereMock: jest.Mock;
  let buildMock: jest.Mock;
  let txExecuteMock: jest.Mock;
  let transactionMock: jest.Mock;

  beforeEach(() => {
    jwtService = {
      signAsync: jest.fn().mockResolvedValue('signed.jwt.token'),
      verifyAsync: jest.fn().mockResolvedValue({ orderItemId: 7 }),
    };
    service = new TicketsService(jwtService as never);

    ticketCreateMock = jest.fn().mockResolvedValue(sampleTicket);
    (db.orm.public.Ticket as unknown as { select: jest.Mock }).select = jest
      .fn()
      .mockReturnValue({ create: ticketCreateMock });

    ticketFirstMock = jest.fn().mockResolvedValue(undefined);
    ticketWhereMock = jest.fn().mockReturnValue({
      select: jest.fn().mockReturnValue({ first: ticketFirstMock }),
    });
    (db.orm.public.Ticket as unknown as { where: jest.Mock }).where =
      ticketWhereMock;

    // Raw SQL builder path (see tickets.service.ts's comment on `validate`
    // for why this isn't `db.orm...update()`): `db.sql.public.ticket
    // .update(fields).where(fn).build()`, then `db.transaction((tx) =>
    // tx.execute(plan))`.
    buildMock = jest.fn().mockReturnValue({ __plan: 'ticket-update' });
    sqlWhereMock = jest.fn().mockReturnValue({ build: buildMock });
    sqlUpdateMock = jest.fn().mockReturnValue({ where: sqlWhereMock });
    (db.sql.public.ticket as unknown as { update: jest.Mock }).update =
      sqlUpdateMock;

    txExecuteMock = jest.fn().mockResolvedValue({ affectedRows: 0 });
    transactionMock = jest
      .fn()
      .mockImplementation((cb: (tx: { execute: jest.Mock }) => unknown) =>
        cb({ execute: txExecuteMock }),
      );
    (db.transaction as unknown as jest.Mock) = transactionMock;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('generateForOrderItem', () => {
    it('signs a QR payload carrying the orderItemId and persists a "valid" ticket', async () => {
      const result = await service.generateForOrderItem(7);

      expect(jwtService.signAsync).toHaveBeenCalledWith(
        { orderItemId: 7 },
        { secret: 'test-ticket-qr-secret' },
      );
      expect(ticketCreateMock).toHaveBeenCalledWith({
        orderItemId: 7,
        qrCodePayload: 'signed.jwt.token',
        status: 'valid',
      });
      expect(result).toEqual(sampleTicket);
    });
  });

  describe('validate', () => {
    it('rejects a forged/tampered payload without ever touching the database', async () => {
      jwtService.verifyAsync.mockRejectedValue(new Error('invalid signature'));

      const result = await service.validate('garbage-or-tampered-token');

      expect(result).toEqual({
        valid: false,
        reason: 'QR Code inválido ou adulterado',
      });
      expect(transactionMock).not.toHaveBeenCalled();
    });

    it('marks a valid ticket as used via the raw SQL conditional update, then reads it back', async () => {
      txExecuteMock.mockResolvedValue({ affectedRows: 1 });
      ticketFirstMock.mockResolvedValue({ ...sampleTicket, status: 'used' });

      const result = await service.validate('signed.jwt.token');

      expect(jwtService.verifyAsync).toHaveBeenCalledWith('signed.jwt.token', {
        secret: 'test-ticket-qr-secret',
      });
      const updateCalls = sqlUpdateMock.mock.calls as unknown as [
        { status: string; usedAt: string },
      ][];
      const updateArg = updateCalls[0][0];
      expect(updateArg.status).toBe('used');
      expect(typeof updateArg.usedAt).toBe('string');
      expect(sqlWhereMock).toHaveBeenCalledWith(expect.any(Function));
      expect(buildMock).toHaveBeenCalled();
      expect(txExecuteMock).toHaveBeenCalledWith({ __plan: 'ticket-update' });
      expect(ticketWhereMock).toHaveBeenCalledWith({
        qrCodePayload: 'signed.jwt.token',
      });
      expect(result).toEqual({
        valid: true,
        ticket: { ...sampleTicket, status: 'used' },
      });
    });

    it('reports "already used" when the conditional update matched no row but the ticket exists', async () => {
      txExecuteMock.mockResolvedValue({ affectedRows: 0 });
      ticketFirstMock.mockResolvedValue({ ...sampleTicket, status: 'used' });

      const result = await service.validate('signed.jwt.token');

      expect(result).toEqual({
        valid: false,
        reason: 'Ingresso já utilizado',
        ticket: { ...sampleTicket, status: 'used' },
      });
    });

    it('reports "not found" when no ticket matches the payload at all', async () => {
      txExecuteMock.mockResolvedValue({ affectedRows: 0 });
      ticketFirstMock.mockResolvedValue(undefined);

      const result = await service.validate('signed.jwt.token');

      expect(result).toEqual({
        valid: false,
        reason: 'Ingresso não encontrado',
      });
    });
  });
});
