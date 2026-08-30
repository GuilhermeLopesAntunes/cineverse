import {
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { db } from '../../prisma/db';
import { PaymentsService } from './payments.service';

interface Chain {
  where: jest.Mock;
  select: jest.Mock;
  orderBy: jest.Mock;
  first: jest.Mock;
  all: jest.Mock;
  update: jest.Mock;
}

function makeChain(): Chain {
  const chain = {} as Chain;
  chain.where = jest.fn().mockReturnValue(chain);
  chain.select = jest.fn().mockReturnValue(chain);
  chain.orderBy = jest.fn().mockReturnValue(chain);
  chain.first = jest.fn();
  chain.all = jest.fn().mockResolvedValue([]);
  chain.update = jest.fn().mockResolvedValue(undefined);
  return chain;
}

interface FakeTx {
  orm: {
    public: {
      Payment: { where: jest.Mock; select: jest.Mock };
      Order: { where: jest.Mock };
    };
  };
}

jest.mock('../../prisma/db', () => ({
  db: {
    orm: {
      public: {
        Order: {},
        OrderItem: {},
        Payment: {},
      },
    },
    transaction: jest.fn(),
  },
}));

describe('PaymentsService', () => {
  let service: PaymentsService;
  let pixProvider: { createCharge: jest.Mock };
  let walletProvider: { charge: jest.Mock };
  let cardGatewayProvider: { charge: jest.Mock };
  let partnerGateway: { confirmSale: jest.Mock };
  let seatLockService: { releaseSeats: jest.Mock };
  let ticketsService: { generateForOrderItem: jest.Mock };
  let orderChain: Chain;
  let paymentChain: Chain;
  let orderItemChain: Chain;
  let paymentCreateMock: jest.Mock;
  let transactionMock: jest.Mock;
  let txPaymentUpdateMock: jest.Mock;
  let txOrderUpdateMock: jest.Mock;
  let txPaymentCreateMock: jest.Mock;

  const sampleOrder = {
    id: 1,
    userId: 42,
    sessionId: 7,
    status: 'pending',
    totalAmountCents: 5000,
  };
  const sampleOrderItems = [
    { id: 201, seatId: 101 },
    { id: 202, seatId: 102 },
  ];
  const samplePayment = {
    id: 10,
    orderId: 1,
    method: 'pix',
    providerRef: 'mock-pix-abc',
    status: 'pending',
    createdAt: 'now',
  };

  beforeEach(() => {
    pixProvider = {
      createCharge: jest.fn().mockResolvedValue({
        providerRef: 'mock-pix-abc',
        copyPasteCode: 'FAKE-CODE',
      }),
    };
    walletProvider = {
      charge: jest.fn().mockResolvedValue({
        providerRef: 'mock-wallet-abc',
        status: 'paid',
      }),
    };
    cardGatewayProvider = {
      charge: jest.fn().mockResolvedValue({
        providerRef: 'mock-card-abc',
        status: 'paid',
      }),
    };
    partnerGateway = {
      confirmSale: jest.fn().mockResolvedValue({ success: true }),
    };
    seatLockService = { releaseSeats: jest.fn().mockResolvedValue([]) };
    ticketsService = {
      generateForOrderItem: jest.fn().mockResolvedValue({
        id: 1,
        orderItemId: 201,
        qrCodePayload: 'signed.jwt.token',
        status: 'valid',
        usedAt: null,
        createdAt: 'now',
      }),
    };
    service = new PaymentsService(
      pixProvider,
      walletProvider,
      cardGatewayProvider,
      partnerGateway as never,
      seatLockService as never,
      ticketsService as never,
    );

    orderChain = makeChain();
    orderChain.first.mockResolvedValue(sampleOrder);
    paymentChain = makeChain();
    paymentChain.first.mockResolvedValue(undefined); // no existing payment, by default
    orderItemChain = makeChain();
    orderItemChain.all.mockResolvedValue(sampleOrderItems);

    (db.orm.public.Order as unknown as { where: jest.Mock }).where = jest
      .fn()
      .mockReturnValue(orderChain);
    (db.orm.public.Payment as unknown as { where: jest.Mock }).where = jest
      .fn()
      .mockReturnValue(paymentChain);
    (db.orm.public.OrderItem as unknown as { where: jest.Mock }).where = jest
      .fn()
      .mockReturnValue(orderItemChain);

    paymentCreateMock = jest.fn().mockResolvedValue(samplePayment);
    (db.orm.public.Payment as unknown as { select: jest.Mock }).select = jest
      .fn()
      .mockReturnValue({ create: paymentCreateMock });

    txPaymentUpdateMock = jest.fn().mockResolvedValue(undefined);
    txOrderUpdateMock = jest.fn().mockResolvedValue(undefined);
    txPaymentCreateMock = jest.fn().mockResolvedValue({
      ...samplePayment,
      providerRef: 'mock-wallet-abc',
      status: 'paid',
    });
    transactionMock = jest
      .fn()
      .mockImplementation(
        async (callback: (tx: FakeTx) => Promise<unknown>) => {
          const tx: FakeTx = {
            orm: {
              public: {
                Payment: {
                  where: jest
                    .fn()
                    .mockReturnValue({ update: txPaymentUpdateMock }),
                  select: jest
                    .fn()
                    .mockReturnValue({ create: txPaymentCreateMock }),
                },
                Order: {
                  where: jest
                    .fn()
                    .mockReturnValue({ update: txOrderUpdateMock }),
                },
              },
            },
          };
          return callback(tx);
        },
      );
    (db.transaction as unknown as jest.Mock) = transactionMock;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('create', () => {
    it('throws NotFoundException when the order does not exist', async () => {
      orderChain.first.mockResolvedValue(undefined);

      await expect(
        service.create(42, 999, { method: 'pix' }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('throws ForbiddenException when the order belongs to someone else', async () => {
      await expect(
        service.create(999, 1, { method: 'pix' }),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('throws ConflictException when the order is not pending', async () => {
      orderChain.first.mockResolvedValue({ ...sampleOrder, status: 'paid' });

      await expect(
        service.create(42, 1, { method: 'pix' }),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('throws ConflictException when a payment already exists for the order', async () => {
      paymentChain.first.mockResolvedValue(samplePayment);

      await expect(
        service.create(42, 1, { method: 'pix' }),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(paymentCreateMock).not.toHaveBeenCalled();
    });

    it('creates a Pix charge and returns the copy-paste code', async () => {
      const result = await service.create(42, 1, { method: 'pix' });

      expect(pixProvider.createCharge).toHaveBeenCalledWith(5000, '1');
      expect(paymentCreateMock).toHaveBeenCalledWith({
        orderId: 1,
        method: 'pix',
        providerRef: 'mock-pix-abc',
        status: 'pending',
      });
      expect(result).toEqual({ ...samplePayment, copyPasteCode: 'FAKE-CODE' });
    });

    it('charges the wallet token and marks both payment and order paid on success', async () => {
      const result = await service.create(42, 1, {
        method: 'apple_pay',
        token: 'tok_abc',
      });

      expect(walletProvider.charge).toHaveBeenCalledWith('tok_abc', 5000, '1');
      expect(txPaymentCreateMock).toHaveBeenCalledWith({
        orderId: 1,
        method: 'apple_pay',
        providerRef: 'mock-wallet-abc',
        status: 'paid',
      });
      expect(txOrderUpdateMock).toHaveBeenCalledWith({ status: 'paid' });
      expect(result).toEqual({
        ...samplePayment,
        providerRef: 'mock-wallet-abc',
        status: 'paid',
      });
      // BE-30: a paid wallet charge settles the order — confirms the sale
      // with the partner per seat and releases the Redis lock.
      expect(partnerGateway.confirmSale).toHaveBeenCalledWith(7, 101, 1);
      expect(partnerGateway.confirmSale).toHaveBeenCalledWith(7, 102, 1);
      expect(seatLockService.releaseSeats).toHaveBeenCalledWith(
        7,
        [101, 102],
        42,
      );
      // BE-32: one signed QR ticket per OrderItem (not per seat id).
      expect(ticketsService.generateForOrderItem).toHaveBeenCalledWith(201);
      expect(ticketsService.generateForOrderItem).toHaveBeenCalledWith(202);
    });

    it('records a failed wallet charge without marking the order paid or settling it', async () => {
      walletProvider.charge.mockResolvedValue({
        providerRef: 'mock-wallet-failed',
        status: 'failed',
      });

      await service.create(42, 1, {
        method: 'google_pay',
        token: 'tok_bad',
      });

      expect(txPaymentCreateMock).toHaveBeenCalledWith({
        orderId: 1,
        method: 'google_pay',
        providerRef: 'mock-wallet-failed',
        status: 'failed',
      });
      expect(txOrderUpdateMock).not.toHaveBeenCalled();
      expect(partnerGateway.confirmSale).not.toHaveBeenCalled();
      expect(seatLockService.releaseSeats).not.toHaveBeenCalled();
      expect(ticketsService.generateForOrderItem).not.toHaveBeenCalled();
    });

    it('charges the card gateway (not the wallet provider) and marks both payment and order paid on success', async () => {
      txPaymentCreateMock.mockResolvedValue({
        ...samplePayment,
        providerRef: 'mock-card-abc',
        status: 'paid',
      });

      const result = await service.create(42, 1, {
        method: 'card',
        token: 'tok_card_abc',
      });

      expect(cardGatewayProvider.charge).toHaveBeenCalledWith(
        'tok_card_abc',
        5000,
        '1',
      );
      expect(walletProvider.charge).not.toHaveBeenCalled();
      expect(txPaymentCreateMock).toHaveBeenCalledWith({
        orderId: 1,
        method: 'card',
        providerRef: 'mock-card-abc',
        status: 'paid',
      });
      expect(txOrderUpdateMock).toHaveBeenCalledWith({ status: 'paid' });
      expect(result).toEqual({
        ...samplePayment,
        providerRef: 'mock-card-abc',
        status: 'paid',
      });
      expect(partnerGateway.confirmSale).toHaveBeenCalledWith(7, 101, 1);
      expect(partnerGateway.confirmSale).toHaveBeenCalledWith(7, 102, 1);
      expect(seatLockService.releaseSeats).toHaveBeenCalledWith(
        7,
        [101, 102],
        42,
      );
      expect(ticketsService.generateForOrderItem).toHaveBeenCalledWith(201);
      expect(ticketsService.generateForOrderItem).toHaveBeenCalledWith(202);
    });

    it('records a failed card charge without marking the order paid or settling it', async () => {
      cardGatewayProvider.charge.mockResolvedValue({
        providerRef: 'mock-card-failed',
        status: 'failed',
      });

      await service.create(42, 1, {
        method: 'card',
        token: 'tok_card_bad',
      });

      expect(txPaymentCreateMock).toHaveBeenCalledWith({
        orderId: 1,
        method: 'card',
        providerRef: 'mock-card-failed',
        status: 'failed',
      });
      expect(txOrderUpdateMock).not.toHaveBeenCalled();
      expect(partnerGateway.confirmSale).not.toHaveBeenCalled();
      expect(seatLockService.releaseSeats).not.toHaveBeenCalled();
      expect(ticketsService.generateForOrderItem).not.toHaveBeenCalled();
    });
  });

  describe('listByOrder', () => {
    it('throws ForbiddenException when the order belongs to someone else', async () => {
      await expect(service.listByOrder(999, 1)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it('lists payments after confirming ownership', async () => {
      paymentChain.all.mockResolvedValue([samplePayment]);

      const result = await service.listByOrder(42, 1);

      expect(result).toEqual([samplePayment]);
    });
  });

  describe('handlePixWebhook', () => {
    it('throws NotFoundException when the providerRef is unknown', async () => {
      paymentChain.first.mockResolvedValue(undefined);

      await expect(
        service.handlePixWebhook({ providerRef: 'nope', status: 'paid' }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('is a no-op when the payment is already settled (idempotent)', async () => {
      paymentChain.first.mockResolvedValue({
        ...samplePayment,
        status: 'paid',
      });

      await service.handlePixWebhook({
        providerRef: 'mock-pix-abc',
        status: 'paid',
      });

      expect(transactionMock).not.toHaveBeenCalled();
      expect(partnerGateway.confirmSale).not.toHaveBeenCalled();
      expect(seatLockService.releaseSeats).not.toHaveBeenCalled();
      expect(ticketsService.generateForOrderItem).not.toHaveBeenCalled();
    });

    it('marks both the payment and the order as paid, and settles the order (BE-30/32), on a "paid" webhook', async () => {
      paymentChain.first.mockResolvedValue(samplePayment);

      await service.handlePixWebhook({
        providerRef: 'mock-pix-abc',
        status: 'paid',
      });

      expect(txPaymentUpdateMock).toHaveBeenCalledWith({ status: 'paid' });
      expect(txOrderUpdateMock).toHaveBeenCalledWith({ status: 'paid' });
      expect(partnerGateway.confirmSale).toHaveBeenCalledWith(7, 101, 1);
      expect(partnerGateway.confirmSale).toHaveBeenCalledWith(7, 102, 1);
      expect(seatLockService.releaseSeats).toHaveBeenCalledWith(
        7,
        [101, 102],
        42,
      );
      expect(ticketsService.generateForOrderItem).toHaveBeenCalledWith(201);
      expect(ticketsService.generateForOrderItem).toHaveBeenCalledWith(202);
    });

    it('marks only the payment as failed on a "failed" webhook, leaving the order alone and not settling it', async () => {
      paymentChain.first.mockResolvedValue(samplePayment);

      await service.handlePixWebhook({
        providerRef: 'mock-pix-abc',
        status: 'failed',
      });

      expect(txPaymentUpdateMock).toHaveBeenCalledWith({ status: 'failed' });
      expect(txOrderUpdateMock).not.toHaveBeenCalled();
      expect(partnerGateway.confirmSale).not.toHaveBeenCalled();
      expect(seatLockService.releaseSeats).not.toHaveBeenCalled();
      expect(ticketsService.generateForOrderItem).not.toHaveBeenCalled();
    });

    it('is a no-op (including no settlement) when the Order backing a paid payment cannot be found', async () => {
      paymentChain.first.mockResolvedValue(samplePayment);
      orderChain.first.mockResolvedValue(undefined);

      await service.handlePixWebhook({
        providerRef: 'mock-pix-abc',
        status: 'paid',
      });

      expect(txOrderUpdateMock).toHaveBeenCalledWith({ status: 'paid' });
      expect(partnerGateway.confirmSale).not.toHaveBeenCalled();
      expect(seatLockService.releaseSeats).not.toHaveBeenCalled();
      expect(ticketsService.generateForOrderItem).not.toHaveBeenCalled();
    });
  });
});
