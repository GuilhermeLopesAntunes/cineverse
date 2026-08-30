import 'package:equatable/equatable.dart';

import 'entities/cinema_partner.dart';
import 'entities/session_with_movie.dart';

class NearbySessionsResult extends Equatable {
  const NearbySessionsResult({required this.partner, required this.sessions});

  final CinemaPartner partner;
  final List<SessionWithMovie> sessions;

  @override
  List<Object?> get props => [partner, sessions];
}
