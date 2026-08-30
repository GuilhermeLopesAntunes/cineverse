import 'package:equatable/equatable.dart';

/// `text` é anulável de propósito: `null` significa "spoiler não revelado",
/// nunca "resenha vazia" — a ofuscação é feita no servidor
/// (`GET /reviews` some com `hasSpoiler:true`), o app nunca recebe o texto
/// real de um item não revelado.
class Review extends Equatable {
  const Review({
    required this.id,
    required this.userId,
    required this.movieId,
    required this.text,
    required this.rating,
    required this.hasSpoiler,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final int movieId;
  final String? text;
  final int rating;
  final bool hasSpoiler;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    userId,
    movieId,
    text,
    rating,
    hasSpoiler,
    createdAt,
  ];
}
