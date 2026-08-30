import 'package:equatable/equatable.dart';

/// `GET/PUT /users/me/profile` — o Prisma `UserProfile` não guarda nenhum
/// outro campo além de `userId`; `favoriteGenres` vem de uma tabela à parte
/// (`FavoriteGenre`, uma linha por gênero) e chega já achatada em lista.
class UserProfile extends Equatable {
  const UserProfile({required this.userId, required this.favoriteGenres});

  final int userId;
  final List<String> favoriteGenres;

  @override
  List<Object?> get props => [userId, favoriteGenres];
}
