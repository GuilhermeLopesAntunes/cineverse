import '../../../core/api/api_client.dart';
import 'models/user_profile_model.dart';

class ProfileApi {
  ProfileApi(this._apiClient);

  final ApiClient _apiClient;

  /// Deixa o 404 subir — é o repositório quem decide que "perfil não
  /// configurado" é estado vazio, não erro (CLAUDE.md, armadilha 9).
  Future<UserProfileModel> fetchProfile() async {
    final response = await _apiClient.dio.get('/users/me/profile');
    return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserProfileModel> updateFavoriteGenres(
    List<String> favoriteGenres,
  ) async {
    final response = await _apiClient.dio.put(
      '/users/me/profile',
      data: {'favoriteGenres': favoriteGenres},
    );
    return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
  }
}
