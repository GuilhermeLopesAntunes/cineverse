import '../../domain/entities/session.dart';

/// Espelha `SessionResponse`: `{ id, movieId, roomId, datetime, priceCents }`.
class SessionModel {
  const SessionModel({
    required this.id,
    required this.movieId,
    required this.roomId,
    required this.datetime,
    required this.priceCents,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] as int,
      movieId: json['movieId'] as int,
      roomId: json['roomId'] as int,
      datetime: json['datetime'] as String,
      priceCents: json['priceCents'] as int,
    );
  }

  final int id;
  final int movieId;
  final int roomId;
  final String datetime;
  final int priceCents;

  Session toEntity() {
    return Session(
      id: id,
      movieId: movieId,
      roomId: roomId,
      datetime: DateTime.parse(datetime).toLocal(),
      priceCents: priceCents,
    );
  }
}
