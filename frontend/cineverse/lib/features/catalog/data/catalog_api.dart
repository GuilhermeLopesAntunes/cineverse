import '../../../core/api/api_client.dart';
import '../../../core/utils/paginated.dart';
import 'models/movie_model.dart';

class CatalogApi {
  CatalogApi(this._apiClient);

  final ApiClient _apiClient;

  Future<Paginated<MovieModel>> fetchMovies({
    required int page,
    required int pageSize,
    String? category,
  }) async {
    final response = await _apiClient.dio.get(
      '/catalog/movies',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        // ignore: use_null_aware_elements
        if (category != null) 'category': category,
      },
    );
    return Paginated.fromJson(
      response.data as Map<String, dynamic>,
      (item) => MovieModel.fromJson(item as Map<String, dynamic>),
    );
  }
}
