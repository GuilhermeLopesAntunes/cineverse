import 'package:equatable/equatable.dart';

import '../../../catalog/domain/entities/movie.dart';
import 'session.dart';

/// `GET /sessions/nearby` só devolve `movieId` — título e pôster vêm do
/// catálogo já carregado nesta sessão do app (mesma junção que o feed faz
/// para resenhas; ver CLAUDE.md § Regra número um, item 1). `movie` é
/// `null` quando esse filme ainda não passou pela tela de catálogo.
class SessionWithMovie extends Equatable {
  const SessionWithMovie({required this.session, required this.movie});

  final Session session;
  final Movie? movie;

  @override
  List<Object?> get props => [session, movie];
}
