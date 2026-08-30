part of 'nearby_sessions_bloc.dart';

enum StateStatus { initial, loading, success, failure }

enum LocationIssue {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
}

class NearbySessionsState extends Equatable {
  const NearbySessionsState({
    this.status = StateStatus.initial,
    this.partner,
    this.sessions = const [],
    this.failure,
    this.locationIssue,
  });

  final StateStatus status;
  final CinemaPartner? partner;
  final List<SessionWithMovie> sessions;
  final Failure? failure;
  final LocationIssue? locationIssue;

  @override
  List<Object?> get props => [
    status,
    partner,
    sessions,
    failure,
    locationIssue,
  ];
}
