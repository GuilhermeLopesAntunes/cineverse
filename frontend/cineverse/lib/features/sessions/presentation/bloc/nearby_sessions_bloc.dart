import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/location/location_service.dart';
import '../../domain/entities/cinema_partner.dart';
import '../../domain/entities/session_with_movie.dart';
import '../../domain/sessions_repository.dart';

part 'nearby_sessions_event.dart';
part 'nearby_sessions_state.dart';

class NearbySessionsBloc
    extends Bloc<NearbySessionsEvent, NearbySessionsState> {
  NearbySessionsBloc(this._sessionsRepository, this._locationService)
    : super(const NearbySessionsState()) {
    on<NearbySessionsRequested>(_onRequested);
  }

  final SessionsRepository _sessionsRepository;
  final LocationService _locationService;

  Future<void> _onRequested(
    NearbySessionsRequested event,
    Emitter<NearbySessionsState> emit,
  ) async {
    emit(const NearbySessionsState(status: StateStatus.loading));

    final locationResult = await _locationService.getCurrentLocation();
    switch (locationResult) {
      case LocationCoordinates(:final latitude, :final longitude):
        await _fetchNearby(latitude, longitude, emit);
      case LocationPermissionDenied():
        emit(
          const NearbySessionsState(
            status: StateStatus.failure,
            locationIssue: LocationIssue.permissionDenied,
          ),
        );
      case LocationPermissionDeniedForever():
        emit(
          const NearbySessionsState(
            status: StateStatus.failure,
            locationIssue: LocationIssue.permissionDeniedForever,
          ),
        );
      case LocationServiceDisabled():
        emit(
          const NearbySessionsState(
            status: StateStatus.failure,
            locationIssue: LocationIssue.serviceDisabled,
          ),
        );
    }
  }

  Future<void> _fetchNearby(
    double latitude,
    double longitude,
    Emitter<NearbySessionsState> emit,
  ) async {
    try {
      final result = await _sessionsRepository.fetchNearby(
        lat: latitude,
        lng: longitude,
      );
      emit(
        NearbySessionsState(
          status: StateStatus.success,
          partner: result.partner,
          sessions: result.sessions,
        ),
      );
    } on NotFoundFailure {
      // Nenhum parceiro cadastrado — estado vazio explicativo, não erro.
      emit(const NearbySessionsState(status: StateStatus.success));
    } on Failure catch (failure) {
      emit(NearbySessionsState(status: StateStatus.failure, failure: failure));
    }
  }
}
