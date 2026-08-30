import '../../../core/api/api_client.dart';
import 'models/login_response_model.dart';

/// Chamadas HTTP cruas de `features/auth`. Não conhece `Failure` nem
/// entidade de domínio — propaga `DioException`, traduzida pelo repositório.
class AuthApi {
  AuthApi(this._apiClient);

  final ApiClient _apiClient;

  Future<LoginResponseModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return LoginResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> register({
    required String email,
    required String password,
    String? name,
  }) async {
    await _apiClient.dio.post(
      '/auth/register',
      data: {'email': email, 'password': password, 'name': ?name},
    );
  }
}
