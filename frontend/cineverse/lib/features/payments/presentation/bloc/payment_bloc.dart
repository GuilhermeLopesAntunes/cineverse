import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/payment.dart';
import '../../domain/payments_repository.dart';

part 'payment_event.dart';
part 'payment_state.dart';

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  PaymentBloc(this._paymentsRepository, this._orderId)
    : super(const PaymentState()) {
    on<PaymentSubmitted>(_onSubmitted);
    on<PaymentPollTicked>(_onPollTicked);
  }

  final PaymentsRepository _paymentsRepository;
  final int _orderId;
  Timer? _pollTimer;

  Future<void> _onSubmitted(
    PaymentSubmitted event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(status: PaymentStatus.submitting));
    try {
      final payment = await _paymentsRepository.createPayment(
        orderId: _orderId,
        method: event.method,
        token: event.token,
      );

      if (payment.method == 'pix') {
        emit(
          state.copyWith(
            status: PaymentStatus.awaitingPixConfirmation,
            payment: payment,
          ),
        );
        _pollTimer = Timer.periodic(
          const Duration(seconds: 3),
          (_) => add(const PaymentPollTicked()),
        );
        return;
      }

      // Carteira/cartão confirmam na própria resposta — sem polling.
      emit(
        state.copyWith(
          status: payment.isPaid ? PaymentStatus.paid : PaymentStatus.failed,
          payment: payment,
        ),
      );
    } on Failure catch (failure) {
      emit(state.copyWith(status: PaymentStatus.error, failure: failure));
    }
  }

  Future<void> _onPollTicked(
    PaymentPollTicked event,
    Emitter<PaymentState> emit,
  ) async {
    if (state.pollTicks + 1 >= maxPollTicks) {
      _pollTimer?.cancel();
      emit(
        state.copyWith(
          status: PaymentStatus.pollTimedOut,
          pollTicks: state.pollTicks + 1,
        ),
      );
      return;
    }

    try {
      final payments = await _paymentsRepository.fetchPayments(_orderId);
      final matches = payments.where((p) => p.id == state.payment?.id);
      final current = matches.isEmpty ? state.payment : matches.first;

      if (current != null && current.isPaid) {
        _pollTimer?.cancel();
        emit(state.copyWith(status: PaymentStatus.paid, payment: current));
        return;
      }
      if (current != null && current.isFailed) {
        _pollTimer?.cancel();
        emit(state.copyWith(status: PaymentStatus.failed, payment: current));
        return;
      }
      emit(state.copyWith(pollTicks: state.pollTicks + 1));
    } on Failure {
      // Falha pontual de rede não interrompe o polling — tenta de novo no
      // próximo tique.
      emit(state.copyWith(pollTicks: state.pollTicks + 1));
    }
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
