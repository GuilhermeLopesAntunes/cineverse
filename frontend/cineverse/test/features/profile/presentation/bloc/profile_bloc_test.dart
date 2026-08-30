import 'package:bloc_test/bloc_test.dart';
import 'package:cineverse/core/error/failure.dart';
import 'package:cineverse/features/profile/domain/entities/user_profile.dart';
import 'package:cineverse/features/profile/domain/profile_repository.dart';
import 'package:cineverse/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late MockProfileRepository profileRepository;

  setUp(() {
    profileRepository = MockProfileRepository();
  });

  group('ProfileRequested', () {
    blocTest<ProfileBloc, ProfileState>(
      'carrega e-mail e gêneros favoritos com sucesso',
      setUp: () {
        when(() => profileRepository.currentEmail())
            .thenAnswer((_) async => 'dev@cineverse.local');
        when(() => profileRepository.fetchProfile()).thenAnswer(
          (_) async => const UserProfile(
            userId: 1,
            favoriteGenres: ['Ação', 'Drama'],
          ),
        );
      },
      build: () => ProfileBloc(profileRepository),
      act: (bloc) => bloc.add(const ProfileRequested()),
      expect: () => [
        const ProfileState(status: StateStatus.loading),
        const ProfileState(
          status: StateStatus.success,
          email: 'dev@cineverse.local',
          favoriteGenres: ['Ação', 'Drama'],
        ),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'perfil ainda não criado (404 -> null) vira gêneros vazios, não falha',
      setUp: () {
        when(() => profileRepository.currentEmail())
            .thenAnswer((_) async => 'dev@cineverse.local');
        when(() => profileRepository.fetchProfile())
            .thenAnswer((_) async => null);
      },
      build: () => ProfileBloc(profileRepository),
      act: (bloc) => bloc.add(const ProfileRequested()),
      expect: () => [
        const ProfileState(status: StateStatus.loading),
        const ProfileState(
          status: StateStatus.success,
          email: 'dev@cineverse.local',
        ),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'falha de rede emite failure',
      setUp: () {
        when(() => profileRepository.currentEmail())
            .thenAnswer((_) async => 'dev@cineverse.local');
        when(() => profileRepository.fetchProfile())
            .thenThrow(const NetworkFailure());
      },
      build: () => ProfileBloc(profileRepository),
      act: (bloc) => bloc.add(const ProfileRequested()),
      expect: () => [
        const ProfileState(status: StateStatus.loading),
        const ProfileState(
          status: StateStatus.failure,
          failure: NetworkFailure(),
        ),
      ],
    );
  });

  group('ProfileEditToggled', () {
    blocTest<ProfileBloc, ProfileState>(
      'entrar em edição semeia selectedGenres com os favoritos atuais',
      build: () => ProfileBloc(profileRepository),
      seed: () => const ProfileState(
        status: StateStatus.success,
        favoriteGenres: ['Terror'],
      ),
      act: (bloc) => bloc.add(const ProfileEditToggled()),
      expect: () => [
        const ProfileState(
          status: StateStatus.success,
          favoriteGenres: ['Terror'],
          isEditing: true,
          selectedGenres: {'Terror'},
        ),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'cancelar edição limpa selectedGenres',
      build: () => ProfileBloc(profileRepository),
      seed: () => const ProfileState(
        status: StateStatus.success,
        favoriteGenres: ['Terror'],
        isEditing: true,
        selectedGenres: {'Terror'},
      ),
      act: (bloc) => bloc.add(const ProfileEditToggled()),
      expect: () => [
        const ProfileState(
          status: StateStatus.success,
          favoriteGenres: ['Terror'],
        ),
      ],
    );
  });

  group('ProfileGenreToggled', () {
    blocTest<ProfileBloc, ProfileState>(
      'adiciona um gênero ainda não selecionado',
      build: () => ProfileBloc(profileRepository),
      seed: () => const ProfileState(
        status: StateStatus.success,
        isEditing: true,
        selectedGenres: {'Ação'},
      ),
      act: (bloc) => bloc.add(const ProfileGenreToggled('Comédia')),
      expect: () => [
        const ProfileState(
          status: StateStatus.success,
          isEditing: true,
          selectedGenres: {'Ação', 'Comédia'},
        ),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'remove um gênero já selecionado',
      build: () => ProfileBloc(profileRepository),
      seed: () => const ProfileState(
        status: StateStatus.success,
        isEditing: true,
        selectedGenres: {'Ação', 'Comédia'},
      ),
      act: (bloc) => bloc.add(const ProfileGenreToggled('Ação')),
      expect: () => [
        const ProfileState(
          status: StateStatus.success,
          isEditing: true,
          selectedGenres: {'Comédia'},
        ),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'ignora toque fora do modo de edição',
      build: () => ProfileBloc(profileRepository),
      seed: () => const ProfileState(status: StateStatus.success),
      act: (bloc) => bloc.add(const ProfileGenreToggled('Ação')),
      expect: () => [],
    );
  });

  group('ProfileSaveRequested', () {
    blocTest<ProfileBloc, ProfileState>(
      'salva com sucesso: substituição total, sai do modo de edição',
      setUp: () => when(
        () => profileRepository.updateFavoriteGenres(['Ação']),
      ).thenAnswer(
        (_) async => const UserProfile(userId: 1, favoriteGenres: ['Ação']),
      ),
      build: () => ProfileBloc(profileRepository),
      seed: () => const ProfileState(
        status: StateStatus.success,
        isEditing: true,
        selectedGenres: {'Ação'},
      ),
      act: (bloc) => bloc.add(const ProfileSaveRequested()),
      expect: () => [
        const ProfileState(
          status: StateStatus.success,
          isEditing: true,
          selectedGenres: {'Ação'},
          saveStatus: SaveStatus.saving,
        ),
        const ProfileState(
          status: StateStatus.success,
          favoriteGenres: ['Ação'],
        ),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'falha ao salvar mantém o modo de edição para nova tentativa',
      setUp: () => when(
        () => profileRepository.updateFavoriteGenres(['Ação']),
      ).thenThrow(const ServerFailure()),
      build: () => ProfileBloc(profileRepository),
      seed: () => const ProfileState(
        status: StateStatus.success,
        isEditing: true,
        selectedGenres: {'Ação'},
      ),
      act: (bloc) => bloc.add(const ProfileSaveRequested()),
      expect: () => [
        const ProfileState(
          status: StateStatus.success,
          isEditing: true,
          selectedGenres: {'Ação'},
          saveStatus: SaveStatus.saving,
        ),
        const ProfileState(
          status: StateStatus.success,
          isEditing: true,
          selectedGenres: {'Ação'},
          saveStatus: SaveStatus.failure,
          failure: ServerFailure(),
        ),
      ],
    );
  });
}
