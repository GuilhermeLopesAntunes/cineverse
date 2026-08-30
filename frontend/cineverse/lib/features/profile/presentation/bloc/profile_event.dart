part of 'profile_bloc.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Primeira carga da tela: e-mail (do token) + perfil (favoriteGenres).
final class ProfileRequested extends ProfileEvent {
  const ProfileRequested();
}

/// Liga/desliga o modo de edição dos gêneros favoritos.
final class ProfileEditToggled extends ProfileEvent {
  const ProfileEditToggled();
}

final class ProfileGenreToggled extends ProfileEvent {
  const ProfileGenreToggled(this.genre);

  final String genre;

  @override
  List<Object?> get props => [genre];
}

final class ProfileSaveRequested extends ProfileEvent {
  const ProfileSaveRequested();
}
