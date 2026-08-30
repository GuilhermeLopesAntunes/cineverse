import 'package:bloc_test/bloc_test.dart';
import 'package:cineverse/core/error/failure.dart';
import 'package:cineverse/features/orders/domain/entities/combo_item.dart';
import 'package:cineverse/features/orders/domain/entities/order.dart';
import 'package:cineverse/features/orders/domain/orders_repository.dart';
import 'package:cineverse/features/orders/presentation/bloc/checkout_bloc.dart';
import 'package:cineverse/features/orders/presentation/checkout_args.dart';
import 'package:cineverse/features/seats/domain/entities/seat.dart';
import 'package:cineverse/features/seats/domain/seat_lock_result.dart';
import 'package:cineverse/features/seats/domain/seats_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSeatsRepository extends Mock implements SeatsRepository {}

class MockOrdersRepository extends Mock implements OrdersRepository {}

void main() {
  late MockSeatsRepository seatsRepository;
  late MockOrdersRepository ordersRepository;

  final args = CheckoutArgs(
    sessionId: 1,
    partnerId: 10,
    priceCentsPerSeat: 3200,
    movieId: 1,
    sessionDatetime: DateTime(2026, 9, 1, 20),
    seats: const [Seat(seatId: 1, code: 'A1', status: SeatStatus.available)],
  );

  setUp(() {
    seatsRepository = MockSeatsRepository();
    ordersRepository = MockOrdersRepository();
    registerFallbackValue(<({int seatId, int? comboItemId})>[]);
    // `close()` libera os assentos de forma best-effort sempre que o pedido
    // não foi criado — stub padrão para não quebrar testes que não
    // verificam essa chamada especificamente.
    when(
      () => seatsRepository.releaseSeats(
        sessionId: any(named: 'sessionId'),
        seatIds: any(named: 'seatIds'),
      ),
    ).thenAnswer((_) async => const []);
  });

  blocTest<CheckoutBloc, CheckoutState>(
    'lock com success:false não avança para combos',
    setUp: () =>
        when(
          () => seatsRepository.lockSeats(
            sessionId: any(named: 'sessionId'),
            seatIds: any(named: 'seatIds'),
          ),
        ).thenAnswer(
          (_) async => const SeatLockResult(
            success: false,
            reason: 'Assento indisponível',
          ),
        ),
    build: () => CheckoutBloc(seatsRepository, ordersRepository),
    act: (bloc) => bloc.add(CheckoutStarted(args)),
    expect: () => [
      CheckoutState(
        status: CheckoutStatus.locking,
        sessionId: 1,
        partnerId: 10,
        seats: args.seats,
        priceCentsPerSeat: 3200,
      ),
      CheckoutState(
        status: CheckoutStatus.lockRejected,
        sessionId: 1,
        partnerId: 10,
        seats: args.seats,
        priceCentsPerSeat: 3200,
        lockRejectReason: 'Assento indisponível',
      ),
    ],
    verify: (_) {
      verifyNever(() => ordersRepository.fetchCombos(any()));
    },
  );

  blocTest<CheckoutBloc, CheckoutState>(
    'lock com sucesso inicia o cronômetro de 300s e busca combos',
    setUp: () {
      when(
        () => seatsRepository.lockSeats(
          sessionId: any(named: 'sessionId'),
          seatIds: any(named: 'seatIds'),
        ),
      ).thenAnswer((_) async => const SeatLockResult(success: true));
      when(() => ordersRepository.fetchCombos(any())).thenAnswer(
        (_) async => const [
          ComboItem(id: 1, partnerId: 10, name: 'Pipoca', priceCents: 1500),
        ],
      );
    },
    build: () => CheckoutBloc(seatsRepository, ordersRepository),
    act: (bloc) => bloc.add(CheckoutStarted(args)),
    wait: const Duration(milliseconds: 10),
    verify: (bloc) {
      expect(bloc.state.status, CheckoutStatus.ready);
      expect(bloc.state.remainingSeconds, 300);
      expect(bloc.state.combos, hasLength(1));
    },
  );

  blocTest<CheckoutBloc, CheckoutState>(
    'cronômetro chegando a zero libera a seleção e volta ao mapa',
    setUp: () {
      when(
        () => seatsRepository.lockSeats(
          sessionId: any(named: 'sessionId'),
          seatIds: any(named: 'seatIds'),
        ),
      ).thenAnswer((_) async => const SeatLockResult(success: true));
      when(
        () => ordersRepository.fetchCombos(any()),
      ).thenAnswer((_) async => const []);
      when(
        () => seatsRepository.releaseSeats(
          sessionId: any(named: 'sessionId'),
          seatIds: any(named: 'seatIds'),
        ),
      ).thenAnswer((_) async => [1]);
    },
    build: () => CheckoutBloc(seatsRepository, ordersRepository),
    seed: () => CheckoutState(
      status: CheckoutStatus.ready,
      sessionId: 1,
      partnerId: 10,
      seats: args.seats,
      priceCentsPerSeat: 3200,
      remainingSeconds: 1,
    ),
    act: (bloc) => bloc.add(const CheckoutTimerTicked()),
    expect: () => [
      isA<CheckoutState>()
          .having((s) => s.status, 'status', CheckoutStatus.lockExpired)
          .having((s) => s.remainingSeconds, 'remainingSeconds', 0),
    ],
    verify: (_) {
      verify(
        () => seatsRepository.releaseSeats(
          sessionId: any(named: 'sessionId'),
          seatIds: any(named: 'seatIds'),
        ),
      ).called(1);
    },
  );

  blocTest<CheckoutBloc, CheckoutState>(
    '409 na criação do pedido volta ao mapa em vez de repetir a requisição',
    setUp: () {
      when(
        () => seatsRepository.lockSeats(
          sessionId: any(named: 'sessionId'),
          seatIds: any(named: 'seatIds'),
        ),
      ).thenAnswer((_) async => const SeatLockResult(success: true));
      when(
        () => ordersRepository.fetchCombos(any()),
      ).thenAnswer((_) async => const []);
      when(
        () => ordersRepository.createOrder(
          sessionId: any(named: 'sessionId'),
          items: any(named: 'items'),
        ),
      ).thenThrow(
        const ConflictFailure(
          'Reserve o(s) assento(s) antes de finalizar a compra: 1',
        ),
      );
    },
    build: () => CheckoutBloc(seatsRepository, ordersRepository),
    seed: () => CheckoutState(
      status: CheckoutStatus.ready,
      sessionId: 1,
      partnerId: 10,
      seats: args.seats,
      priceCentsPerSeat: 3200,
      remainingSeconds: 200,
    ),
    act: (bloc) => bloc.add(const OrderSubmitted()),
    expect: () => [
      isA<CheckoutState>().having(
        (s) => s.status,
        'status',
        CheckoutStatus.submittingOrder,
      ),
      isA<CheckoutState>().having(
        (s) => s.status,
        'status',
        CheckoutStatus.lockExpired,
      ),
    ],
  );

  blocTest<CheckoutBloc, CheckoutState>(
    'pedido criado com sucesso emite orderCreated com o pedido do servidor',
    setUp: () {
      when(
        () => seatsRepository.lockSeats(
          sessionId: any(named: 'sessionId'),
          seatIds: any(named: 'seatIds'),
        ),
      ).thenAnswer((_) async => const SeatLockResult(success: true));
      when(
        () => ordersRepository.fetchCombos(any()),
      ).thenAnswer((_) async => const []);
      when(
        () => ordersRepository.createOrder(
          sessionId: any(named: 'sessionId'),
          items: any(named: 'items'),
        ),
      ).thenAnswer(
        (_) async => Order(
          id: 1,
          userId: 1,
          sessionId: 1,
          status: 'pending',
          totalAmountCents: 3200,
          createdAt: DateTime(2026, 1, 1),
          items: const [OrderItem(seatId: 1, comboItemId: null)],
        ),
      );
    },
    build: () => CheckoutBloc(seatsRepository, ordersRepository),
    seed: () => CheckoutState(
      status: CheckoutStatus.ready,
      sessionId: 1,
      partnerId: 10,
      seats: args.seats,
      priceCentsPerSeat: 3200,
      remainingSeconds: 200,
    ),
    act: (bloc) => bloc.add(const OrderSubmitted()),
    expect: () => [
      isA<CheckoutState>().having(
        (s) => s.status,
        'status',
        CheckoutStatus.submittingOrder,
      ),
      isA<CheckoutState>()
          .having((s) => s.status, 'status', CheckoutStatus.orderCreated)
          .having((s) => s.order?.id, 'order.id', 1),
    ],
  );
}
