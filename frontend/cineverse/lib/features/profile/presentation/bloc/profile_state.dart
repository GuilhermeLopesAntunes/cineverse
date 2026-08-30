part of 'profile_bloc.dart';

enum StateStatus { initial, loading, success, failure }

enum SaveStatus { idle, saving, failure }

class ProfileState extends Equatable {
  const ProfileState({
    this.status = StateStatus.initial,
    this.email,
    this.favoriteGenres = const [],
    this.isEditing = false,
    this.selectedGenres = const {},
    this.saveStatus = SaveStatus.idle,
    this.failure,
  });

  final StateStatus status;
  final String? email;
  final List<String> favoriteGenres;
  final bool isEditing;
  final Set<String> selectedGenres;
  final SaveStatus saveStatus;
  final Failure? failure;

  ProfileState copyWith({
    StateStatus? status,
    String? email,
    List<String>? favoriteGenres,
    bool? isEditing,
    Set<String>? selectedGenres,
    SaveStatus? saveStatus,
    Failure? failure,
  }) {
    return ProfileState(
      status: status ?? this.status,
      email: email ?? this.email,
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      isEditing: isEditing ?? this.isEditing,
      selectedGenres: selectedGenres ?? this.selectedGenres,
      saveStatus: saveStatus ?? this.saveStatus,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    email,
    favoriteGenres,
    isEditing,
    selectedGenres,
    saveStatus,
    failure,
  ];
}
