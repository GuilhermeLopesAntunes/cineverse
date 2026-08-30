import 'package:dio/dio.dart';

import '../auth/session_expiry_notifier.dart';
import '../storage/token_storage.dart';

/// Injeta `Authorization: Bearer <accessToken>` em toda requisição que tiver
/// token guardado. Ao ver `401`, limpa o armazenamento seguro e notifica —
/// não existe renovação de token no backend (`auth.controller.ts` só tem
/// `register`/`login`), então 401 é sempre fim de sessão, nunca retry.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage, this._sessionExpiryNotifier);

  final TokenStorage _tokenStorage;
  final SessionExpiryNotifier _sessionExpiryNotifier;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await _tokenStorage.clear();
      _sessionExpiryNotifier.notify();
    }
    handler.next(err);
  }
}
