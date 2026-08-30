import '../../../core/utils/paginated.dart';
import 'entities/movie.dart';
import 'entities/movie_category.dart';

abstract class CatalogRepository {
  /// Busca uma página e a soma ao cache em memória usado pelas junções que
  /// a API não faz (ex.: `feed` resolvendo título/pôster por `movieId`).
  /// `category` filtra por `releaseDate` no próprio backend (ver
  /// `MovieCategoryFilter`); omitido, devolve o catálogo inteiro sem filtro.
  Future<Paginated<Movie>> fetchMovies({
    required int page,
    int pageSize = 20,
    MovieCategory? category,
  });

  /// Lookup síncrono no cache — `null` se o filme ainda não foi carregado
  /// nesta sessão do app.
  Movie? movieById(int id);
}
