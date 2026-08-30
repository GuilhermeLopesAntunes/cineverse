import 'package:bloc_test/bloc_test.dart';
import 'package:cineverse/core/error/failure.dart';
import 'package:cineverse/core/location/location_service.dart';
import 'package:cineverse/features/sessions/domain/entities/cinema_partner.dart';
import 'package:cineverse/features/sessions/domain/entities/session.dart';
import 'package:cineverse/features/sessions/domain/entities/session_with_movie.dart';
import 'package:cineverse/features/sessions/domain/nearby_sessions_result.dart';
import 'package:cineverse/features/sessions/domain/sessions_repository.dart';
import 'package:cineverse/features/sessions/presentation/bloc/nearby_sessions_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSessionsRepository extends Mock implements SessionsRepository {}

class MockLocationService extends Mock implements LocationService {}

void main() {
  late MockSessionsRepository sessionsRepository;
  late MockLocationService locationService;

  const partner = CinemaPartner(id: 1, name: 'Cine Teste', distanceKm: 2.5);
  final session = Session(
    id: 10,
    movieId: 1,
    roomId: 1,
    datetime: DateTime(2026, 9, 1, 20),
    priceCents: 3200,
  );
  final sessionWithMovie = SessionWithMovie(session: session, movie: null);

  setUp(() {
    sessionsRepository = MockSessionsRepository();
    locationService = MockLocationService();
  });

  group('NearbySessionsRequested', () {
    blocTest<NearbySessionsBloc, NearbySessionsState>(
      'localização concedida e parceiro encontrado emite success',
      setUp: () {
        when(() => locationService.getCurrentLocation()).thenAnswer(
          (_) async =>
              const LocationCoordinates(latitude: -23.5, longitude: -46.6),
        );
        when(
          () => sessionsRepository.fetchNearby(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
          ),
        ).thenAnswer(
          (_) async =>
              NearbySessionsResult(partner: partner, sessions: [sessionWithMovie]),
        );
      },
      build: () => NearbySessionsBloc(sessionsRepository, locationService),
      act: (bloc) => bloc.add(const NearbySessionsRequested()),
      expect: () => [
        const NearbySessionsState(status: StateStatus.loading),
        NearbySessionsState(
          status: StateStatus.success,
          partner: partner,
          sessions: [sessionWithMovie],
        ),
      ],
    );

    blocTest<NearbySessionsBloc, NearbySessionsState>(
      '404 (nenhum parceiro cadastrado) emite success vazio, não failure',
      setUp: () {
        when(() => locationService.getCurrentLocation()).thenAnswer(
          (_) async =>
              const LocationCoordinates(latitude: -23.5, longitude: -46.6),
        );
        when(
          () => sessionsRepository.fetchNearby(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
          ),
        ).thenThrow(const NotFoundFailure());
      },
      build: () => NearbySessionsBloc(sessionsRepository, locationService),
      act: (bloc) => bloc.add(const NearbySessionsRequested()),
      expect: () => [
        const NearbySessionsState(status: StateStatus.loading),
        const NearbySessionsState(status: StateStatus.success),
      ],
    );

    blocTest<NearbySessionsBloc, NearbySessionsState>(
      'permissão de localização negada permanentemente emite locationIssue',
      setUp: () => when(
        () => locationService.getCurrentLocation(),
      ).thenAnswer((_) async => const LocationPermissionDeniedForever()),
      build: () => NearbySessionsBloc(sessionsRepository, locationService),
      act: (bloc) => bloc.add(const NearbySessionsRequested()),
      expect: () => [
        const NearbySessionsState(status: StateStatus.loading),
        const NearbySessionsState(
          status: StateStatus.failure,
          locationIssue: LocationIssue.permissionDeniedForever,
        ),
      ],
      verify: (_) {
        verifyNever(
          () => sessionsRepository.fetchNearby(
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
          ),
        );
      },
    );
  });
}
