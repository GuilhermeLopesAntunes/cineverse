part of 'payment_bloc.dart';

sealed class PaymentEvent extends Equatable {
  const PaymentEvent();

  @override
  List<Object?> get props => [];
}

/// `token` é obrigatório para tudo além de `pix` — gerado no cliente,
/// simulado (não existe SDK real de gateway nesta versão).
final class PaymentSubmitted extends PaymentEvent {
  const PaymentSubmitted({required this.method, this.token});

  final String method;
  final String? token;

  @override
  List<Object?> get props => [method, token];
}

/// Um tique a cada 3s — vindo de um `Timer`, nunca `emit` direto do callback.
final class PaymentPollTicked extends PaymentEvent {
  const PaymentPollTicked();
}
