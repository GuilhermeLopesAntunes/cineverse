import 'package:equatable/equatable.dart';

/// `GET /reviews/:id/share` — metadados prontos do servidor para a share
/// sheet nativa. O app não monta texto de compartilhamento por conta própria.
class ReviewShare extends Equatable {
  const ReviewShare({
    required this.url,
    required this.title,
    required this.text,
  });

  final String url;
  final String title;
  final String text;

  @override
  List<Object?> get props => [url, title, text];
}
