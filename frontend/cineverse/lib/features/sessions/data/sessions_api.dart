import '../../../core/api/api_client.dart';
import 'models/nearby_sessions_response_model.dart';

class SessionsApi {
  SessionsApi(this._apiClient);

  final ApiClient _apiClient;

  /// `404` quando não há nenhum parceiro cadastrado — propagado como
  /// `DioException`, traduzido pelo repositório.
  Future<NearbySessionsResponseModel> fetchNearby({
    required double lat,
    required double lng,
  }) async {
    final response = await _apiClient.dio.get(
      '/sessions/nearby',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    return NearbySessionsResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
