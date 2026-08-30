import '../../domain/entities/user_profile.dart';

/// Espelha literalmente `{ userId, favoriteGenres }` de
/// `GET/PUT /users/me/profile`.
class UserProfileModel {
  const UserProfileModel({required this.userId, required this.favoriteGenres});

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      userId: json['userId'] as int,
      favoriteGenres: (json['favoriteGenres'] as List)
          .cast<String>(),
    );
  }

  final int userId;
  final List<String> favoriteGenres;

  UserProfile toEntity() {
    return UserProfile(userId: userId, favoriteGenres: favoriteGenres);
  }
}
