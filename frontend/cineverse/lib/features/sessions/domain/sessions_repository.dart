import 'nearby_sessions_result.dart';

abstract class SessionsRepository {
  /// Lança [NotFoundFailure] quando não há parceiro cadastrado — a UI trata
  /// isso como estado vazio, não como erro (ver ARQUITETURA_FRONTEND.md § 7.4).
  Future<NearbySessionsResult> fetchNearby({
    required double lat,
    required double lng,
  });
}
