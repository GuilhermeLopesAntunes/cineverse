import 'package:equatable/equatable.dart';

/// `GET /sessions/nearby` (dentro de `sessions`) e `GET /sessions?roomId=`.
/// Não traz `partnerId` — só existe em `CinemaPartner.id`, ver ARQUITETURA_FRONTEND.md
/// § 11 atrito 4.
class Session extends Equatable {
  const Session({
    required this.id,
    required this.movieId,
    required this.roomId,
    required this.datetime,
    required this.priceCents,
  });

  final int id;
  final int movieId;
  final int roomId;
  final DateTime datetime;
  final int priceCents;

  @override
  List<Object?> get props => [id, movieId, roomId, datetime, priceCents];
}
