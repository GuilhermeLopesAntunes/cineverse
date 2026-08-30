part of 'nearby_sessions_bloc.dart';

sealed class NearbySessionsEvent extends Equatable {
  const NearbySessionsEvent();

  @override
  List<Object?> get props => [];
}

final class NearbySessionsRequested extends NearbySessionsEvent {
  const NearbySessionsRequested();
}
