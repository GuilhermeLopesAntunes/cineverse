import '../../../core/api/api_client.dart';
import 'models/seat_model.dart';

/// `{ success, reason? }` — vem em `201` mesmo quando `success:false`; não é
/// erro HTTP, é resultado de domínio.
class SeatLockResultModel {
  const SeatLockResultModel({required this.success, this.reason});

  factory SeatLockResultModel.fromJson(Map<String, dynamic> json) {
    return SeatLockResultModel(
      success: json['success'] as bool,
      reason: json['reason'] as String?,
    );
  }

  final bool success;
  final String? reason;
}

class SeatsApi {
  SeatsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<SeatModel>> fetchSeatMap(int sessionId) async {
    final response = await _apiClient.dio.get('/sessions/$sessionId/seats/map');
    return (response.data as List)
        .map((item) => SeatModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Tudo ou nada — até 20 assentos por chamada.
  Future<SeatLockResultModel> lockSeats(
    int sessionId,
    List<int> seatIds,
  ) async {
    final response = await _apiClient.dio.post(
      '/sessions/$sessionId/seats/lock',
      data: {'seatIds': seatIds},
    );
    return SeatLockResultModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Devolve só os `seatIds` realmente liberados — nunca a lista enviada.
  Future<List<int>> releaseSeats(int sessionId, List<int> seatIds) async {
    final response = await _apiClient.dio.post(
      '/sessions/$sessionId/seats/release',
      data: {'seatIds': seatIds},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['releasedSeatIds'] as List).cast<int>();
  }
}
