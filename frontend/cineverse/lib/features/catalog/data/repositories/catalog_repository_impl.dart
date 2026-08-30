import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/utils/paginated.dart';
import '../../domain/catalog_repository.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/movie_category.dart';
import '../catalog_api.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl(this._catalogApi, this._failureMapper);

  final CatalogApi _catalogApi;
  final FailureMapper _failureMapper;

  /// Cache em memória, vivo pela sessão do app — é a fonte das junções que
  /// `feed` e `catalog/:movieId` precisam e a API não faz.
  final Map<int, Movie> _cache = {};

  @override
  Future<Paginated<Movie>> fetchMovies({
    required int page,
    int pageSize = 20,
    MovieCategory? category,
  }) async {
    try {
      final response = await _catalogApi.fetchMovies(
        page: page,
        pageSize: pageSize,
        category: category?.queryValue,
      );
      final movies = response.items.map((model) => model.toEntity()).toList();
      for (final movie in movies) {
        _cache[movie.id] = movie;
      }
      return Paginated(
        items: movies,
        page: response.page,
        pageSize: response.pageSize,
        total: response.total,
        totalPages: response.totalPages,
      );
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }

  @override
  Movie? movieById(int id) => _cache[id];
}
