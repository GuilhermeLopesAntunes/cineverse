import 'package:equatable/equatable.dart';

/// `GET /catalog/movies` — não existe `GET /catalog/movies/:id`; o detalhe é
/// sempre montado a partir do item já carregado nesta lista.
class Movie extends Equatable {
  const Movie({
    required this.id,
    required this.tmdbId,
    required this.title,
    required this.synopsis,
    required this.posterUrl,
    required this.cachedAt,
    this.releaseDate,
  });

  final int id;
  final int tmdbId;
  final String title;
  final String? synopsis;
  final String? posterUrl;
  final DateTime cachedAt;

  /// `null` quando o TMDB não anunciou uma data para o filme — o backend não
  /// inventa uma categoria nesse caso (ver `MovieCategoryFilter` no
  /// backend), então o cliente também não deve.
  final DateTime? releaseDate;

  @override
  List<Object?> get props => [
    id,
    tmdbId,
    title,
    synopsis,
    posterUrl,
    cachedAt,
    releaseDate,
  ];
}
