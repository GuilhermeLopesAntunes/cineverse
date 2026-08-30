import { INestApplication } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { ticketQrConfig } from '../src/common/config/ticket-qr.config';
import { OrdersService } from '../src/modules/orders/orders.service';
import { PaymentsService } from '../src/modules/payments/payments.service';
import { SeatLockService } from '../src/modules/seats/seat-lock.service';
import { db } from '../src/prisma/db';
import { AppModule } from './../src/app.module';

// BE-25's literal acceptance criterion ("checkout único gera múltiplos
// ingressos vinculados à mesma order") now closes for real, now that
// Ticket exists (BE-32): a single group checkout produces one Order with
// one OrderItem per seat (already true since BE-24/26), and — once
// payment settles (BE-30) — one signed QR Ticket per OrderItem, every one
// of them traceable back to the same Order.
describe('Group order (e2e)', () => {
  let app: INestApplication;
  let seatLockService: SeatLockService;
  let ordersService: OrdersService;
  let paymentsService: PaymentsService;
  let jwtService: JwtService;
  let userId: number;
  let partnerId: number;
  let roomId: number;
  let seatIds: number[];
  let movieId: number;
  let sessionId: number;
  let orderId: number;
  let comboId: number;

  const priceCents = 1500;
  const seatCount = 3;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
    seatLockService = app.get(SeatLockService);
    ordersService = app.get(OrdersService);
    paymentsService = app.get(PaymentsService);
    jwtService = app.get(JwtService);

    const user = await db.orm.public.User.create({
      email: `group-order-test-${Date.now()}@example.com`,
      passwordHash: 'not-a-real-hash',
      name: 'Group Order Test',
    });
    userId = user.id;

    const partner = await db.orm.public.CinemaPartner.create({
      name: `Group Order Test Cinema ${Date.now()}`,
      latitude: 0,
      longitude: 0,
    });
    partnerId = partner.id;

    const room = await db.orm.public.Room.create({
      partnerId,
      name: `Group Order Test Room ${Date.now()}`,
    });
    roomId = room.id;

    const seats = await Promise.all(
      Array.from({ length: seatCount }, (_, i) =>
        db.orm.public.Seat.create({ roomId, code: `G${i + 1}` }),
      ),
    );
    seatIds = seats.map((s) => s.id);

    const movie = await db.orm.public.Movie.create({
      tmdbId: -(Date.now() % 2_000_000_000) - 1, // distinct from other e2e specs' movies
      title: 'Group Order Test Movie',
    });
    movieId = movie.id;

    const session = await db.orm.public.Session.create({
      movieId,
      roomId,
      datetime: new Date().toISOString(),
      priceCents,
    });
    sessionId = session.id;
  });

  afterAll(async () => {
    if (orderId) {
      // Cascades: deleting OrderItem takes its Ticket with it
      // (Ticket.orderItemId), deleting Order takes its Payment with it
      // (Payment.orderId) — no separate Ticket/Payment cleanup needed.
      await db.orm.public.OrderItem.where({ orderId }).delete();
      await db.orm.public.Order.where({ id: orderId }).delete();
    }
    // Only after the OrderItem referencing it is gone — the FK has no
    // cascade (a combo isn't expected to disappear out from under an order
    // that already used it), so deleting it first would violate it.
    if (comboId) {
      await db.orm.public.ComboItem.where({ id: comboId }).delete();
    }
    await db.transaction(async (tx) => {
      const deleteStatePlan = tx.sql.public.partnerSeatState
        .delete()
        .where((p, fns) => fns.eq(p.sessionId, sessionId))
        .build();
      await tx.execute(deleteStatePlan);
    });
    await db.orm.public.Session.where({ id: sessionId }).delete();
    for (const seatId of seatIds) {
      await db.orm.public.Seat.where({ id: seatId }).delete();
    }
    await db.orm.public.Room.where({ id: roomId }).delete();
    await db.orm.public.CinemaPartner.where({ id: partnerId }).delete();
    await db.orm.public.Movie.where({ id: movieId }).delete();
    await db.orm.public.User.where({ id: userId }).delete();

    await app.close();
  });

  it('locks every seat, then checks out once into a single Order with one OrderItem per seat (one with a combo, BE-26)', async () => {
    const lockResult = await seatLockService.lockSeats(
      sessionId,
      seatIds,
      userId,
    );
    expect(lockResult.success).toBe(true);

    const combo = await db.orm.public.ComboItem.create({
      partnerId,
      name: 'Pipoca + Refri',
      priceCents: 1800,
    });
    comboId = combo.id;

    const order = await ordersService.create(userId, {
      sessionId,
      items: seatIds.map((seatId, i) => ({
        seatId,
        comboItemId: i === 0 ? combo.id : undefined,
      })),
    });
    orderId = order.id;

    expect(order.status).toBe('pending');
    // 3 seats + one combo on the first
    expect(order.totalAmountCents).toBe(priceCents * seatCount + 1800);
    expect(order.items.map((i) => i.seatId).sort()).toEqual(
      [...seatIds].sort(),
    );
    expect(order.items.find((i) => i.seatId === seatIds[0])?.comboItemId).toBe(
      combo.id,
    );

    // Read back from Postgres directly, not the service's return value —
    // proving the rows themselves, not just what create() echoed back.
    const items = await db.orm.public.OrderItem.where({ orderId: order.id })
      .select('id', 'orderId', 'seatId', 'comboItemId')
      .all();
    expect(items).toHaveLength(seatCount);
    expect(items.every((item) => item.orderId === order.id)).toBe(true);
    expect(items.map((item) => item.seatId).sort()).toEqual(
      [...seatIds].sort(),
    );
    expect(items.filter((item) => item.comboItemId === combo.id)).toHaveLength(
      1,
    );

    // Pay via Pix (async webhook) and confirm — closes BE-25's original
    // criterion for real: one checkout, multiple seats, and now multiple
    // Tickets, all traceable back to this same Order.
    const payment = await paymentsService.create(userId, order.id, {
      method: 'pix',
    });
    await paymentsService.handlePixWebhook({
      providerRef: payment.providerRef,
      status: 'paid',
    });

    const tickets = await db.orm.public.Ticket.where((t) =>
      t.orderItemId.in(items.map((item) => item.id)),
    )
      .select('orderItemId', 'qrCodePayload', 'status', 'usedAt')
      .all();
    expect(tickets).toHaveLength(seatCount);
    expect(
      tickets.every((t) => t.status === 'valid' && t.usedAt === null),
    ).toBe(true);
    // Every payload is a distinct signed JWT, verifiable with the ticket
    // secret and carrying back the exact orderItemId it was minted for —
    // not a bare sequential id.
    const payloads = new Set(tickets.map((t) => t.qrCodePayload));
    expect(payloads.size).toBe(seatCount);
    for (const ticket of tickets) {
      const claims = await jwtService.verifyAsync<{ orderItemId: number }>(
        ticket.qrCodePayload,
        { secret: ticketQrConfig.secret },
      );
      expect(claims.orderItemId).toBe(ticket.orderItemId);
    }
  });
});
