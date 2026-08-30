import '../../domain/entities/seat.dart';

/// Espelha `SeatMapEntry`: `{ seatId, code, status }`, `status` sempre
/// `"available" | "locked" | "sold"`.
class SeatModel {
  const SeatModel({
    required this.seatId,
    required this.code,
    required this.status,
  });

  factory SeatModel.fromJson(Map<String, dynamic> json) {
    return SeatModel(
      seatId: json['seatId'] as int,
      code: json['code'] as String,
      status: json['status'] as String,
    );
  }

  final int seatId;
  final String code;
  final String status;

  Seat toEntity() {
    return Seat(
      seatId: seatId,
      code: code,
      status: switch (status) {
        'locked' => SeatStatus.locked,
        'sold' => SeatStatus.sold,
        _ => SeatStatus.available,
      },
    );
  }
}
