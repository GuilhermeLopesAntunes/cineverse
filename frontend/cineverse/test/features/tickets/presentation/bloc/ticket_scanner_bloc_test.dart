import 'package:bloc_test/bloc_test.dart';
import 'package:cineverse/core/error/failure.dart';
import 'package:cineverse/features/tickets/domain/entities/ticket_validation.dart';
import 'package:cineverse/features/tickets/domain/tickets_repository.dart';
import 'package:cineverse/features/tickets/presentation/bloc/ticket_scanner_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTicketsRepository extends Mock implements TicketsRepository {}

void main() {
  late MockTicketsRepository ticketsRepository;

  setUp(() {
    ticketsRepository = MockTicketsRepository();
  });

  blocTest<TicketScannerBloc, TicketScannerState>(
    'QR válido emite result com valid:true',
    setUp: () => when(
      () => ticketsRepository.validate(any()),
    ).thenAnswer((_) async => const TicketValidation(valid: true)),
    build: () => TicketScannerBloc(ticketsRepository),
    act: (bloc) => bloc.add(const QrCodeDetected('payload')),
    expect: () => [
      const TicketScannerState(status: TicketScannerStatus.validating),
      const TicketScannerState(
        status: TicketScannerStatus.result,
        result: TicketValidation(valid: true),
      ),
    ],
  );

  blocTest<TicketScannerBloc, TicketScannerState>(
    'QR já utilizado emite result com o motivo do servidor',
    setUp: () => when(() => ticketsRepository.validate(any())).thenAnswer(
      (_) async =>
          const TicketValidation(valid: false, reason: 'Ingresso já utilizado'),
    ),
    build: () => TicketScannerBloc(ticketsRepository),
    act: (bloc) => bloc.add(const QrCodeDetected('payload')),
    expect: () => [
      const TicketScannerState(status: TicketScannerStatus.validating),
      const TicketScannerState(
        status: TicketScannerStatus.result,
        result: TicketValidation(valid: false, reason: 'Ingresso já utilizado'),
      ),
    ],
  );

  blocTest<TicketScannerBloc, TicketScannerState>(
    'ignora nova leitura enquanto já mostra um resultado',
    setUp: () => when(
      () => ticketsRepository.validate(any()),
    ).thenAnswer((_) async => const TicketValidation(valid: true)),
    build: () => TicketScannerBloc(ticketsRepository),
    seed: () => const TicketScannerState(
      status: TicketScannerStatus.result,
      result: TicketValidation(valid: true),
    ),
    act: (bloc) => bloc.add(const QrCodeDetected('payload-2')),
    expect: () => [],
    verify: (_) {
      verifyNever(() => ticketsRepository.validate(any()));
    },
  );

  blocTest<TicketScannerBloc, TicketScannerState>(
    'ScanAgainRequested volta ao estado inicial de escaneamento',
    build: () => TicketScannerBloc(ticketsRepository),
    seed: () => const TicketScannerState(
      status: TicketScannerStatus.result,
      result: TicketValidation(valid: true),
    ),
    act: (bloc) => bloc.add(const ScanAgainRequested()),
    expect: () => [const TicketScannerState()],
  );

  blocTest<TicketScannerBloc, TicketScannerState>(
    'falha de rede emite error',
    setUp: () => when(
      () => ticketsRepository.validate(any()),
    ).thenThrow(const NetworkFailure()),
    build: () => TicketScannerBloc(ticketsRepository),
    act: (bloc) => bloc.add(const QrCodeDetected('payload')),
    expect: () => [
      const TicketScannerState(status: TicketScannerStatus.validating),
      const TicketScannerState(
        status: TicketScannerStatus.error,
        failure: NetworkFailure(),
      ),
    ],
  );
}
