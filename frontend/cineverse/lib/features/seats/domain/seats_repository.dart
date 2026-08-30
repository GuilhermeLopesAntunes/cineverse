import 'entities/seat.dart';
import 'seat_lock_result.dart';

abstract class SeatsRepository {
  Future<List<Seat>> fetchSeatMap(int sessionId);

  /// Tudo ou nada — máx. 20 assentos.
  Future<SeatLockResult> lockSeats({
    required int sessionId,
    required List<int> seatIds,
  });

  /// Devolve só os `seatIds` que este usuário realmente detinha e liberou.
  Future<List<int>> releaseSeats({
    required int sessionId,
    required List<int> seatIds,
  });
}
