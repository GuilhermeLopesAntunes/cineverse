import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../domain/entities/seat.dart';
import '../../domain/seat_lock_result.dart';
import '../../domain/seats_repository.dart';
import '../seats_api.dart';

class SeatsRepositoryImpl implements SeatsRepository {
  SeatsRepositoryImpl(this._seatsApi, this._failureMapper);

  final SeatsApi _seatsApi;
  final FailureMapper _failureMapper;

  @override
  Future<List<Seat>> fetchSeatMap(int sessionId) async {
    try {
      final models = await _seatsApi.fetchSeatMap(sessionId);
      return models.map((model) => model.toEntity()).toList();
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }

  @override
  Future<SeatLockResult> lockSeats({
    required int sessionId,
    required List<int> seatIds,
  }) async {
    try {
      final result = await _seatsApi.lockSeats(sessionId, seatIds);
      return SeatLockResult(success: result.success, reason: result.reason);
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }

  @override
  Future<List<int>> releaseSeats({
    required int sessionId,
    required List<int> seatIds,
  }) async {
    try {
      return await _seatsApi.releaseSeats(sessionId, seatIds);
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }
}
