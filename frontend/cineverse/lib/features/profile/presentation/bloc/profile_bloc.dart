import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/profile_repository.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc(this._profileRepository) : super(const ProfileState()) {
    on<ProfileRequested>(_onRequested);
    on<ProfileEditToggled>(_onEditToggled);
    on<ProfileGenreToggled>(_onGenreToggled);
    on<ProfileSaveRequested>(_onSaveRequested);
  }

  final ProfileRepository _profileRepository;

  Future<void> _onRequested(
    ProfileRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(status: StateStatus.loading));
    try {
      final email = await _profileRepository.currentEmail();
      final UserProfile? profile = await _profileRepository.fetchProfile();
      emit(
        state.copyWith(
          status: StateStatus.success,
          email: email,
          // Perfil ainda não criado (404 → null no repositório) é estado
          // vazio, não falha — a tela mostra "nenhum gênero" normalmente.
          favoriteGenres: profile?.favoriteGenres ?? const <String>[],
        ),
      );
    } on Failure catch (failure) {
      emit(state.copyWith(status: StateStatus.failure, failure: failure));
    }
  }

  void _onEditToggled(ProfileEditToggled event, Emitter<ProfileState> emit) {
    final startingEdit = !state.isEditing;
    emit(
      state.copyWith(
        isEditing: startingEdit,
        selectedGenres: startingEdit
            ? state.favoriteGenres.toSet()
            : const <String>{},
        saveStatus: SaveStatus.idle,
      ),
    );
  }

  void _onGenreToggled(ProfileGenreToggled event, Emitter<ProfileState> emit) {
    if (!state.isEditing) return;
    final selected = {...state.selectedGenres};
    if (!selected.remove(event.genre)) selected.add(event.genre);
    emit(state.copyWith(selectedGenres: selected));
  }

  Future<void> _onSaveRequested(
    ProfileSaveRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(saveStatus: SaveStatus.saving));
    try {
      final profile = await _profileRepository.updateFavoriteGenres(
        state.selectedGenres.toList(),
      );
      emit(
        state.copyWith(
          favoriteGenres: profile.favoriteGenres,
          isEditing: false,
          selectedGenres: const <String>{},
          saveStatus: SaveStatus.idle,
        ),
      );
    } on Failure catch (failure) {
      emit(state.copyWith(saveStatus: SaveStatus.failure, failure: failure));
    }
  }
}
