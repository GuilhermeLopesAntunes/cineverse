import '../../../core/error/failure.dart';

/// Fronteira de domínio para sessão. Bloc só conhece esta interface — nunca
/// `dio`, `DioException` ou o DTO de resposta do backend.
abstract class AuthRepository {
  /// `true` quando há token guardado. Não valida expiração localmente: o
  /// primeiro `401` de qualquer requisição é quem decide isso (sem endpoint
  /// de renovação, não há como validar sem consultar o servidor).
  Future<bool> hasStoredSession();

  /// Lança [Failure] em caso de erro (401 = credencial inválida).
  Future<void> login({required String email, required String password});

  /// Registra e, em seguida, autentica com as mesmas credenciais — o
  /// backend não devolve token no cadastro, só `{id, email, name, createdAt}`.
  Future<void> register({
    required String email,
    required String password,
    String? name,
  });

  Future<void> logout();
}
