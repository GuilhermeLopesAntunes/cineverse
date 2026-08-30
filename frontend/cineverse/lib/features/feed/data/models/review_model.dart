import '../../domain/entities/review.dart';

/// Espelha `ReviewResponse`: `{ id, userId, movieId, text, rating, hasSpoiler, createdAt }`.
/// Usado tanto por `POST /reviews` (autor vê o texto real, mesmo com spoiler)
/// quanto por `GET /reviews` (texto `null` quando `hasSpoiler:true`) e
/// `GET /reviews/:id/reveal` (texto sempre real).
class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.userId,
    required this.movieId,
    required this.text,
    required this.rating,
    required this.hasSpoiler,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as int,
      userId: json['userId'] as int,
      movieId: json['movieId'] as int,
      text: json['text'] as String?,
      rating: json['rating'] as int,
      hasSpoiler: json['hasSpoiler'] as bool,
      createdAt: json['createdAt'] as String,
    );
  }

  final int id;
  final int userId;
  final int movieId;
  final String? text;
  final int rating;
  final bool hasSpoiler;
  final String createdAt;

  Review toEntity() {
    return Review(
      id: id,
      userId: userId,
      movieId: movieId,
      text: text,
      rating: rating,
      hasSpoiler: hasSpoiler,
      createdAt: DateTime.parse(createdAt).toLocal(),
    );
  }
}
