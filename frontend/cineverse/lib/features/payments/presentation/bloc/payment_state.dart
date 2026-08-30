part of 'payment_bloc.dart';

enum PaymentStatus {
  selectingMethod,
  submitting,
  awaitingPixConfirmation,
  pollTimedOut,
  paid,
  failed,
  error,
}

/// Limite de *polling* do Pix: 5 minutos, o mesmo TTL do lock de assento —
/// depois disso o assento já caiu de qualquer forma.
const maxPollTicks = 100; // 100 * 3s = 300s

class PaymentState extends Equatable {
  const PaymentState({
    this.status = PaymentStatus.selectingMethod,
    this.payment,
    this.pollTicks = 0,
    this.failure,
  });

  final PaymentStatus status;
  final Payment? payment;
  final int pollTicks;
  final Failure? failure;

  PaymentState copyWith({
    PaymentStatus? status,
    Payment? payment,
    int? pollTicks,
    Failure? failure,
  }) {
    return PaymentState(
      status: status ?? this.status,
      payment: payment ?? this.payment,
      pollTicks: pollTicks ?? this.pollTicks,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, payment, pollTicks, failure];
}
