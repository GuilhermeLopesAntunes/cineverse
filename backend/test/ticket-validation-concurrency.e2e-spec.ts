import { INestApplication } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { OrdersService } from '../src/modules/orders/orders.service';
import { PaymentsService } from '../src/modules/payments/payments.service';
import { SeatLockService } from '../src/modules/seats/seat-lock.service';
import { TicketsService } from '../src/modules/tickets/tickets.service';
import { db } from '../src/prisma/db';
import { AppModule } from './../src/app.module';

// RF-14/RNF-12's real guarantee: a ticket QR must be redeemable exactly
// once, even if the same code is scanned from multiple devices at the same
// instant (e.g. a screenshotted/shared QR shown to two different doors).
// This only proves anything against a *real* Postgres — TicketsService's
// atomicity comes from a plain conditional UPDATE (`WHERE qrCodePayload = ?
// AND status = 'valid'`), which only real row-level locking can serialize;
// a mocked DB call would just execute sequentially like any unit test.
describe('Ticket validation concurrency (e2e)', () => {
  let app: INestApplication;
  let ticketsService: TicketsService;
  let userId: number;
  let partnerId: number;
  let roomId: number;
  let seatId: number;
  let movieId: number;
  let sessionId: number;
  let orderId: number;
  let qrCodePayload: string;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
    const seatLockService = app.get(SeatLockService);
    const ordersService = app.get(OrdersService);
    const paymentsService = app.get(PaymentsService);
    ticketsService = app.get(TicketsService);

    const user = await db.orm.public.User.create({
      email: `ticket-validation-test-${Date.now()}@example.com`,
      passwordHash: 'not-a-real-hash',
      name: 'Ticket Validation Test',
    });
    userId = user.id;

    const partner = await db.orm.public.CinemaPartner.create({
      name: `Ticket Validation Test Cinema ${Date.now()}`,
      latitude: 0,
      longitude: 0,
    });
    partnerId = partner.id;

    const room = await db.orm.public.Room.create({
      partnerId,
      name: `Ticket Validation Test Room ${Date.now()}`,
    });
    roomId = room.id;

    const seat = await db.orm.public.Seat.create({ roomId, code: 'V1' });
    seatId = seat.id;

    const movie = await db.orm.public.Movie.create({
      tmdbId: -(Date.now() % 2_000_000_000) - 1,
      title: 'Ticket Validation Test Movie',
    });
    movieId = movie.id;

    const session = await db.orm.public.Session.create({
      movieId,
      roomId,
      datetime: new Date().toISOString(),
      priceCents: 1000,
    });
    sessionId = session.id;

    // Real checkout + payment, end to end, so this test exercises the
    // actual Ticket a buyer would receive — not a hand-crafted row.
    await seatLockService.lockSeats(sessionId, [seatId], userId);
    const order = await ordersService.create(userId, {
      sessionId,
      items: [{ seatId }],
    });
    orderId = order.id;

    const payment = await paymentsService.create(userId, orderId, {
      method: 'pix',
    });
    await paymentsService.handlePixWebhook({
      providerRef: payment.providerRef,
      status: 'paid',
    });

    const orderItem = await db.orm.public.OrderItem.where({ orderId })
      .select('id')
      .first();
    const ticket = await db.orm.public.Ticket.where({
      orderItemId: orderItem?.id,
    })
      .select('qrCodePayload')
      .first();
    qrCodePayload = ticket?.qrCodePayload ?? '';
    expect(qrCodePayload).not.toBe('');
  });

  afterAll(async () => {
    // Cascades: deleting OrderItem takes its Ticket with it, deleting
    // Order takes its Payment with it.
    await db.orm.public.OrderItem.where({ orderId }).delete();
    await db.orm.public.Order.where({ id: orderId }).delete();
    await db.transaction(async (tx) => {
      const deleteStatePlan = tx.sql.public.partnerSeatState
        .delete()
        .where((p, fns) => fns.eq(p.sessionId, sessionId))
        .build();
      await tx.execute(deleteStatePlan);
    });
    await db.orm.public.Session.where({ id: sessionId }).delete();
    await db.orm.public.Seat.where({ id: seatId }).delete();
    await db.orm.public.Room.where({ id: roomId }).delete();
    await db.orm.public.CinemaPartner.where({ id: partnerId }).delete();
    await db.orm.public.Movie.where({ id: movieId }).delete();
    await db.orm.public.User.where({ id: userId }).delete();

    await app.close();
  });

  it('lets exactly one of many concurrent validations of the same QR succeed', async () => {
    const attemptCount = 20;
    const attempts = Array.from({ length: attemptCount }, () =>
      ticketsService.validate(qrCodePayload),
    );

    const results = await Promise.all(attempts);
    const successes = results.filter((r) => r.valid);
    const failures = results.filter((r) => !r.valid);

    expect(successes).toHaveLength(1);
    expect(failures).toHaveLength(attemptCount - 1);
    failures.forEach((f) => expect(f.reason).toBe('Ingresso já utilizado'));
  }, 20000);

  it('keeps reporting "already used" on a later validation attempt', async () => {
    const result = await ticketsService.validate(qrCodePayload);
    expect(result.valid).toBe(false);
    expect(result.reason).toBe('Ingresso já utilizado');
    expect(result.ticket?.status).toBe('used');
  });
});
