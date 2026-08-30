import 'package:bloc_test/bloc_test.dart';
import 'package:cineverse/core/storage/token_storage.dart';
import 'package:cineverse/core/ws/socket_factory.dart';
import 'package:cineverse/features/seats/domain/entities/seat.dart';
import 'package:cineverse/features/seats/domain/seats_repository.dart';
import 'package:cineverse/features/seats/presentation/bloc/seat_map_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class MockSeatsRepository extends Mock implements SeatsRepository {}

class MockSocketFactory extends Mock implements SocketFactory {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockSocket extends Mock implements io.Socket {}

void main() {
  late MockSeatsRepository seatsRepository;
  late MockSocketFactory socketFactory;
  late MockTokenStorage tokenStorage;
  late MockSocket socket;
  late void Function(dynamic)? connectHandler;

  final seats = [
    const Seat(seatId: 1, code: 'A1', status: SeatStatus.available),
    const Seat(seatId: 2, code: 'A2', status: SeatStatus.available),
  ];

  setUpAll(() {
    registerFallbackValue(SocketNamespace.seats);
  });

  setUp(() {
    seatsRepository = MockSeatsRepository();
    socketFactory = MockSocketFactory();
    tokenStorage = MockTokenStorage();
    socket = MockSocket();
    connectHandler = null;

    when(() => tokenStorage.readAccessToken()).thenAnswer((_) async => 'token');
    when(
      () => socketFactory.create(any(), accessToken: any(named: 'accessToken')),
    ).thenReturn(socket);
    when(() => socket.connect()).thenReturn(socket);
    when(() => socket.emit(any(), any())).thenReturn(null);
    when(() => socket.dispose()).thenReturn(null);
    when(() => socket.on(any(), any())).thenAnswer((invocation) {
      final event = invocation.positionalArguments[0] as String;
      if (event == 'connect') {
        connectHandler =
            invocation.positionalArguments[1] as void Function(dynamic);
      }
      return () {};
    });
    when(
      () => seatsRepository.fetchSeatMap(any()),
    ).thenAnswer((_) async => seats);
  });

  blocTest<SeatMapBloc, SeatMapState>(
    'carrega o snapshot e agrupa por fileira',
    build: () => SeatMapBloc(seatsRepository, socketFactory, tokenStorage),
    act: (bloc) => bloc.add(const SeatMapRequested(1)),
    expect: () => [
      const SeatMapState(status: StateStatus.loading, sessionId: 1),
      SeatMapState(
        status: StateStatus.success,
        sessionId: 1,
        seats: seats,
        groupedRows: {'A': seats},
      ),
    ],
  );

  blocTest<SeatMapBloc, SeatMapState>(
    'tocar um assento disponível seleciona; tocar de novo desseleciona',
    build: () => SeatMapBloc(seatsRepository, socketFactory, tokenStorage),
    act: (bloc) async {
      bloc.add(const SeatMapRequested(1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const SeatTapped(1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const SeatTapped(1));
    },
    verify: (bloc) {
      expect(bloc.state.selectedSeatIds, isEmpty);
    },
  );

  blocTest<SeatMapBloc, SeatMapState>(
    'assento selecionado que é travado por outro sai da seleção',
    build: () => SeatMapBloc(seatsRepository, socketFactory, tokenStorage),
    act: (bloc) async {
      bloc.add(const SeatMapRequested(1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const SeatTapped(1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const SeatLockedReceived(1));
    },
    verify: (bloc) {
      expect(bloc.state.selectedSeatIds, isEmpty);
      final seat = bloc.state.seats.firstWhere((s) => s.seatId == 1);
      expect(seat.status, SeatStatus.locked);
    },
  );

  blocTest<SeatMapBloc, SeatMapState>(
    'tocar um assento vendido não faz nada',
    seed: () => SeatMapState(
      status: StateStatus.success,
      sessionId: 1,
      seats: const [Seat(seatId: 1, code: 'A1', status: SeatStatus.sold)],
      groupedRows: const {
        'A': [Seat(seatId: 1, code: 'A1', status: SeatStatus.sold)],
      },
    ),
    build: () => SeatMapBloc(seatsRepository, socketFactory, tokenStorage),
    act: (bloc) => bloc.add(const SeatTapped(1)),
    expect: () => [],
  );

  blocTest<SeatMapBloc, SeatMapState>(
    'reconexão do socket re-dispara SeatMapRequested sem quebrar '
    '(regressão: sessionId era um campo `late final`, e uma segunda '
    'conexão — inclusive a primeira, que já dispara "connect" — lançava '
    'LateInitializationError e derrubava a tela)',
    build: () => SeatMapBloc(seatsRepository, socketFactory, tokenStorage),
    act: (bloc) async {
      bloc.add(const SeatMapRequested(1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // Simula o próprio `socket.connect()` disparando o callback `onConnect`
      // — é exatamente isso que crashava em produção.
      connectHandler!(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      connectHandler!(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    },
    verify: (bloc) {
      expect(bloc.state.status, StateStatus.success);
      expect(bloc.state.sessionId, 1);
      expect(bloc.state.seats, seats);
    },
  );
}
