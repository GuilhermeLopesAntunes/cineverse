import 'package:bloc_test/bloc_test.dart';
import 'package:cineverse/core/error/failure.dart';
import 'package:cineverse/features/payments/domain/entities/payment.dart';
import 'package:cineverse/features/payments/domain/payments_repository.dart';
import 'package:cineverse/features/payments/presentation/bloc/payment_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPaymentsRepository extends Mock implements PaymentsRepository {}

Payment _payment({
  required String method,
  required String status,
  String? copyPasteCode,
  int id = 1,
}) => Payment(
  id: id,
  orderId: 1,
  method: method,
  providerRef: 'ref-$id',
  status: status,
  createdAt: DateTime(2026, 1, 1),
  copyPasteCode: copyPasteCode,
);

void main() {
  late MockPaymentsRepository paymentsRepository;

  setUp(() {
    paymentsRepository = MockPaymentsRepository();
  });

  group('pix', () {
    blocTest<PaymentBloc, PaymentState>(
      'cria pagamento pix e entra em espera, iniciando o polling',
      setUp: () =>
          when(
            () => paymentsRepository.createPayment(
              orderId: any(named: 'orderId'),
              method: any(named: 'method'),
              token: any(named: 'token'),
            ),
          ).thenAnswer(
            (_) async => _payment(
              method: 'pix',
              status: 'pending',
              copyPasteCode: '00020126...',
            ),
          ),
      build: () => PaymentBloc(paymentsRepository, 1),
      act: (bloc) => bloc.add(const PaymentSubmitted(method: 'pix')),
      expect: () => [
        const PaymentState(status: PaymentStatus.submitting),
        PaymentState(
          status: PaymentStatus.awaitingPixConfirmation,
          payment: _payment(
            method: 'pix',
            status: 'pending',
            copyPasteCode: '00020126...',
          ),
        ),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      'polling detecta confirmação e emite paid',
      setUp: () => when(
        () => paymentsRepository.fetchPayments(any()),
      ).thenAnswer((_) async => [_payment(method: 'pix', status: 'paid')]),
      build: () => PaymentBloc(paymentsRepository, 1),
      seed: () => PaymentState(
        status: PaymentStatus.awaitingPixConfirmation,
        payment: _payment(
          method: 'pix',
          status: 'pending',
          copyPasteCode: 'abc',
        ),
      ),
      act: (bloc) => bloc.add(const PaymentPollTicked()),
      expect: () => [
        isA<PaymentState>().having(
          (s) => s.status,
          'status',
          PaymentStatus.paid,
        ),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      'chegar ao limite de tiques sem confirmação emite pollTimedOut',
      build: () => PaymentBloc(paymentsRepository, 1),
      seed: () => PaymentState(
        status: PaymentStatus.awaitingPixConfirmation,
        payment: _payment(
          method: 'pix',
          status: 'pending',
          copyPasteCode: 'abc',
        ),
        pollTicks: maxPollTicks - 1,
      ),
      act: (bloc) => bloc.add(const PaymentPollTicked()),
      expect: () => [
        isA<PaymentState>().having(
          (s) => s.status,
          'status',
          PaymentStatus.pollTimedOut,
        ),
      ],
      verify: (_) {
        verifyNever(() => paymentsRepository.fetchPayments(any()));
      },
    );
  });

  group('carteira/cartão', () {
    blocTest<PaymentBloc, PaymentState>(
      'pagamento síncrono aprovado emite paid sem polling',
      setUp: () => when(
        () => paymentsRepository.createPayment(
          orderId: any(named: 'orderId'),
          method: any(named: 'method'),
          token: any(named: 'token'),
        ),
      ).thenAnswer((_) async => _payment(method: 'card', status: 'paid')),
      build: () => PaymentBloc(paymentsRepository, 1),
      act: (bloc) =>
          bloc.add(const PaymentSubmitted(method: 'card', token: 'sim_1')),
      expect: () => [
        const PaymentState(status: PaymentStatus.submitting),
        PaymentState(
          status: PaymentStatus.paid,
          payment: _payment(method: 'card', status: 'paid'),
        ),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      'pagamento síncrono recusado emite failed',
      setUp: () => when(
        () => paymentsRepository.createPayment(
          orderId: any(named: 'orderId'),
          method: any(named: 'method'),
          token: any(named: 'token'),
        ),
      ).thenAnswer((_) async => _payment(method: 'card', status: 'failed')),
      build: () => PaymentBloc(paymentsRepository, 1),
      act: (bloc) =>
          bloc.add(const PaymentSubmitted(method: 'card', token: 'sim_1')),
      expect: () => [
        const PaymentState(status: PaymentStatus.submitting),
        PaymentState(
          status: PaymentStatus.failed,
          payment: _payment(method: 'card', status: 'failed'),
        ),
      ],
    );

    blocTest<PaymentBloc, PaymentState>(
      '409 (pedido já tem pagamento) emite error, não repete a requisição',
      setUp: () =>
          when(
            () => paymentsRepository.createPayment(
              orderId: any(named: 'orderId'),
              method: any(named: 'method'),
              token: any(named: 'token'),
            ),
          ).thenThrow(
            const ConflictFailure('Pedido 1 já tem um pagamento associado'),
          ),
      build: () => PaymentBloc(paymentsRepository, 1),
      act: (bloc) =>
          bloc.add(const PaymentSubmitted(method: 'card', token: 'sim_1')),
      expect: () => [
        const PaymentState(status: PaymentStatus.submitting),
        const PaymentState(
          status: PaymentStatus.error,
          failure: ConflictFailure('Pedido 1 já tem um pagamento associado'),
        ),
      ],
    );
  });
}
