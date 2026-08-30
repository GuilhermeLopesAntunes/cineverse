import '../../../core/api/api_client.dart';

class NotificationsApi {
  NotificationsApi(this._apiClient);

  final ApiClient _apiClient;

  /// `200`, não `201` — reregistrar o mesmo token é idempotente no backend.
  Future<void> registerPushToken({
    required String token,
    required String platform,
  }) async {
    await _apiClient.dio.post(
      '/push-tokens',
      data: {'token': token, 'platform': platform},
    );
  }
}
