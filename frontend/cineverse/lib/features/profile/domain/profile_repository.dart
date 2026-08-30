import 'entities/user_profile.dart';

abstract class ProfileRepository {
  /// `null` quando o perfil ainda não foi criado (404 — ver CLAUDE.md,
  /// armadilha 9). Isso é estado vazio, não erro.
  Future<UserProfile?> fetchProfile();

  /// Substituição total da lista — não existe endpoint de adicionar/remover
  /// um gênero por vez.
  Future<UserProfile> updateFavoriteGenres(List<String> favoriteGenres);

  /// E-mail da sessão atual, lido do access token guardado — não existe
  /// `GET /users/me` que devolva isso.
  Future<String?> currentEmail();
}
