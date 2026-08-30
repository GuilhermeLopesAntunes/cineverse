import '../../domain/entities/movie.dart';

/// Espelha literalmente o item de `GET /catalog/movies`:
/// `{ id, tmdbId, title, synopsis, posterUrl, cachedAt }`.
class MovieModel {
  const MovieModel({
    required this.id,
    required this.tmdbId,
    required this.title,
    required this.synopsis,
    required this.posterUrl,
    required this.cachedAt,
    this.releaseDate,
  });

  factory MovieModel.fromJson(Map<String, dynamic> json) {
    return MovieModel(
      id: json['id'] as int,
      tmdbId: json['tmdbId'] as int,
      title: json['title'] as String,
      synopsis: json['synopsis'] as String?,
      posterUrl: json['posterUrl'] as String?,
      cachedAt: json['cachedAt'] as String,
      releaseDate: json['releaseDate'] as String?,
    );
  }

  final int id;
  final int tmdbId;
  final String title;
  final String? synopsis;
  final String? posterUrl;
  final String cachedAt;
  final String? releaseDate;

  /// Conversão string ISO → `DateTime` acontece aqui, na fronteira
  /// entidade/DTO — nunca no `fromJson` (ver CLAUDE.md § Datas).
  Movie toEntity() {
    return Movie(
      id: id,
      tmdbId: tmdbId,
      title: title,
      synopsis: synopsis,
      posterUrl: posterUrl,
      cachedAt: DateTime.parse(cachedAt).toLocal(),
      releaseDate: releaseDate == null
          ? null
          : DateTime.parse(releaseDate!).toLocal(),
    );
  }
}
