import 'package:equatable/equatable.dart';

import '../../../catalog/domain/entities/movie.dart';
import 'review.dart';

/// Resenha + filme resolvidos pela junção que a API não faz (`GET /reviews`
/// só devolve `movieId`). `movie` é `null` quando o filme ainda não foi
/// carregado no cache do catálogo nesta sessão — a tela mostra um
/// identificador genérico nesse caso, sem disparar requisição nova.
class FeedEntry extends Equatable {
  const FeedEntry({required this.review, required this.movie});

  final Review review;
  final Movie? movie;

  @override
  List<Object?> get props => [review, movie];
}
