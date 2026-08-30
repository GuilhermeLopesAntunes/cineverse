import 'package:equatable/equatable.dart';

enum SeatStatus { available, locked, sold }

/// `GET /sessions/:id/seats/map` — sem linha/coluna, só `code` (ver
/// `core/utils/seat_code.dart`).
class Seat extends Equatable {
  const Seat({required this.seatId, required this.code, required this.status});

  final int seatId;
  final String code;
  final SeatStatus status;

  Seat copyWith({SeatStatus? status}) {
    return Seat(seatId: seatId, code: code, status: status ?? this.status);
  }

  @override
  List<Object?> get props => [seatId, code, status];
}
