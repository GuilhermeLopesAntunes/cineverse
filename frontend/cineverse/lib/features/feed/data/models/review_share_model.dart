import '../../domain/entities/review_share.dart';

/// Espelha `GET /reviews/:id/share`: `{ url, title, text }`.
class ReviewShareModel {
  const ReviewShareModel({
    required this.url,
    required this.title,
    required this.text,
  });

  factory ReviewShareModel.fromJson(Map<String, dynamic> json) {
    return ReviewShareModel(
      url: json['url'] as String,
      title: json['title'] as String,
      text: json['text'] as String,
    );
  }

  final String url;
  final String title;
  final String text;

  ReviewShare toEntity() => ReviewShare(url: url, title: title, text: text);
}
