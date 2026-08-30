part of 'checkout_bloc.dart';

sealed class CheckoutEvent extends Equatable {
  const CheckoutEvent();

  @override
  List<Object?> get props => [];
}

final class CheckoutStarted extends CheckoutEvent {
  const CheckoutStarted(this.args);

  final CheckoutArgs args;

  @override
  List<Object?> get props => [args];
}

final class ComboSelected extends CheckoutEvent {
  const ComboSelected({required this.seatId, required this.comboItemId});

  final int seatId;
  final int? comboItemId;

  @override
  List<Object?> get props => [seatId, comboItemId];
}

/// Um tique por segundo — vindo de um `Timer`, nunca `emit` direto de dentro
/// do callback (mesma convenção do WS).
final class CheckoutTimerTicked extends CheckoutEvent {
  const CheckoutTimerTicked();
}

final class OrderSubmitted extends CheckoutEvent {
  const OrderSubmitted();
}
