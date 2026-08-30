import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/jwt.dart';

/// Token de sessão em Keychain/Keystore. `SharedPreferences` não serve para
/// token — ver CLAUDE.md § Stack.
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  /// Lê `sub` (userId) do access token guardado — usado só para distinguir
  /// mensagens próprias no chat, nunca para decisão de segurança.
  Future<int?> readUserId() async {
    final token = await readAccessToken();
    if (token == null) return null;
    final payload = decodeJwtPayload(token);
    final sub = payload?['sub'];
    return sub is int ? sub : int.tryParse(sub?.toString() ?? '');
  }

  /// Lê `email` do access token guardado — não existe `GET /users/me` que
  /// devolva isso, e login não retorna o objeto do usuário (só tokens); o
  /// claim `email` do JWT (`auth.service.ts` → `issueTokens`) é a única
  /// fonte desse dado para uma sessão já autenticada.
  Future<String?> readEmail() async {
    final token = await readAccessToken();
    if (token == null) return null;
    final payload = decodeJwtPayload(token);
    return payload?['email'] as String?;
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
