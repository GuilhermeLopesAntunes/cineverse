part of 'seat_map_bloc.dart';

sealed class SeatMapEvent extends Equatable {
  const SeatMapEvent();

  @override
  List<Object?> get props => [];
}

final class SeatMapRequested extends SeatMapEvent {
  const SeatMapRequested(this.sessionId);

  final int sessionId;

  @override
  List<Object?> get props => [sessionId];
}

/// Alterna seleção local — nunca vai ao servidor (a reserva é um passo
/// explícito depois, no checkout).
final class SeatTapped extends SeatMapEvent {
  const SeatTapped(this.seatId);

  final int seatId;

  @override
  List<Object?> get props => [seatId];
}

final class SeatLockedReceived extends SeatMapEvent {
  const SeatLockedReceived(this.seatId);

  final int seatId;

  @override
  List<Object?> get props => [seatId];
}

final class SeatReleasedReceived extends SeatMapEvent {
  const SeatReleasedReceived(this.seatId);

  final int seatId;

  @override
  List<Object?> get props => [seatId];
}

final class SeatSoldReceived extends SeatMapEvent {
  const SeatSoldReceived(this.seatId);

  final int seatId;

  @override
  List<Object?> get props => [seatId];
}
