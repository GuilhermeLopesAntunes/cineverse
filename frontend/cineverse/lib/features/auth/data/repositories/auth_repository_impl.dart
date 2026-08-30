import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/auth_repository.dart';
import '../auth_api.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._authApi, this._tokenStorage, this._failureMapper);

  final AuthApi _authApi;
  final TokenStorage _tokenStorage;
  final FailureMapper _failureMapper;

  @override
  Future<bool> hasStoredSession() async {
    final accessToken = await _tokenStorage.readAccessToken();
    return accessToken != null;
  }

  @override
  Future<void> login({required String email, required String password}) async {
    try {
      final response = await _authApi.login(email: email, password: password);
      await _tokenStorage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      await _authApi.register(email: email, password: password, name: name);
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
    // O backend não devolve token no cadastro — login imediato com as mesmas
    // credenciais é o que dá "cadastro leva direto ao app autenticado".
    await login(email: email, password: password);
  }

  @override
  Future<void> logout() => _tokenStorage.clear();
}
