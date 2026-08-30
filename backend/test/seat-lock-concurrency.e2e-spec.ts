import { INestApplication } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { SeatLockService } from '../src/modules/seats/seat-lock.service';
import { db } from '../src/prisma/db';
import { AppModule } from './../src/app.module';

// The literal acceptance criterion for BE-23 (RNF-08): simulate a
// simultaneous purchase attempt on the same seat and confirm exactly one
// succeeds. This only proves anything against a *real* Redis — a mocked
// ioredis client can't demonstrate atomicity, since the mock would just
// serialize calls the way a plain unit test always does.
describe('SeatLockService concurrency (e2e)', () => {
  let app: INestApplication;
  let seatLockService: SeatLockService;
  let partnerId: number;
  let roomId: number;
  let seatId: number;
  let movieId: number;
  let sessionId: number;
  let winnerUserId: number;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
    seatLockService = app.get(SeatLockService);

    const partner = await db.orm.public.CinemaPartner.create({
      name: `Concurrency Test Cinema ${Date.now()}`,
      latitude: 0,
      longitude: 0,
    });
    partnerId = partner.id;

    const room = await db.orm.public.Room.create({
      partnerId,
      name: `Concurrency Test Room ${Date.now()}`,
    });
    roomId = room.id;

    const seat = await db.orm.public.Seat.create({ roomId, code: 'X1' });
    seatId = seat.id;

    const movie = await db.orm.public.Movie.create({
      // Negative and bounded so it can never collide with a real TMDB id.
      tmdbId: -(Date.now() % 2_000_000_000),
      title: 'Concurrency Test Movie',
    });
    movieId = movie.id;

    const session = await db.orm.public.Session.create({
      movieId,
      roomId,
      datetime: new Date().toISOString(),
      priceCents: 1000,
    });
    sessionId = session.id;
  });

  afterAll(async () => {
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

    await app.close();
  });

  it('lets exactly one of many concurrent lock attempts on the same seat succeed', async () => {
    const attemptCount = 20;
    const userIds = Array.from({ length: attemptCount }, (_, i) => 10_000 + i);
    const attempts = userIds.map((userId) =>
      seatLockService.lockSeats(sessionId, [seatId], userId),
    );

    const results = await Promise.all(attempts);
    const successes = results.filter((r) => r.success);
    const failures = results.filter((r) => !r.success);

    expect(successes).toHaveLength(1);
    expect(failures).toHaveLength(attemptCount - 1);
    failures.forEach((f) => expect(f.reason).toBeDefined());

    // Whichever concurrent attempt actually won is not deterministic — 20
    // requests raced, Redis picked one. Track it so the next test can
    // release the *real* holder, not assume a fixed winner.
    winnerUserId = userIds[results.findIndex((r) => r.success)];
  }, 20000);

  it('lets a losing attempt succeed after the winner releases the seat', async () => {
    const release = await seatLockService.releaseSeats(
      sessionId,
      [seatId],
      winnerUserId,
    );
    expect(release).toEqual([seatId]);

    const result = await seatLockService.lockSeats(sessionId, [seatId], 10_001);
    expect(result.success).toBe(true);
  });
});
