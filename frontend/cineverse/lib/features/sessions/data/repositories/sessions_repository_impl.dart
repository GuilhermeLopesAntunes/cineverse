import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../catalog/domain/catalog_repository.dart';
import '../../domain/entities/session_with_movie.dart';
import '../../domain/nearby_sessions_result.dart';
import '../../domain/sessions_repository.dart';
import '../sessions_api.dart';

class SessionsRepositoryImpl implements SessionsRepository {
  SessionsRepositoryImpl(
    this._sessionsApi,
    this._catalogRepository,
    this._failureMapper,
  );

  final SessionsApi _sessionsApi;
  final CatalogRepository _catalogRepository;
  final FailureMapper _failureMapper;

  @override
  Future<NearbySessionsResult> fetchNearby({
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await _sessionsApi.fetchNearby(lat: lat, lng: lng);
      return NearbySessionsResult(
        partner: response.partner.toEntity(),
        sessions: response.sessions
            .map(
              (model) => SessionWithMovie(
                session: model.toEntity(),
                movie: _catalogRepository.movieById(model.movieId),
              ),
            )
            .toList(),
      );
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }
}
