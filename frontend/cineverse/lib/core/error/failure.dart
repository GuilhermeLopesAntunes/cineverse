/// Falha de domínio, produzida por [FailureMapper] a partir de uma
/// [DioException] ou de uma resposta HTTP fora do 2xx.
///
/// Blocs e widgets tratam exaustivamente via pattern matching (Dart 3):
/// switch (failure) { NetworkFailure() => ..., ConflictFailure(:final message) => ..., }
sealed class Failure {
  const Failure();
}

final class NetworkFailure extends Failure {
  const NetworkFailure();
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure();
}

final class ForbiddenFailure extends Failure {
  const ForbiddenFailure();
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure();
}

/// 409 — a única em que o backend produz texto realmente útil ao usuário
/// final (assento não reservado, pedido já pago, e-mail em uso).
final class ConflictFailure extends Failure {
  const ConflictFailure(this.message);

  final String message;
}

/// 400 — corpo rejeitado pelo `ValidationPipe` global. `messages` nunca é
/// vazio: o mapper normaliza tanto `message: string` quanto `message: string[]`.
final class ValidationFailure extends Failure {
  const ValidationFailure(this.messages);

  final List<String> messages;
}

/// 5xx — o backend não manda detalhe por design; a mensagem exibida é do app.
final class ServerFailure extends Failure {
  const ServerFailure();
}

/// Qualquer falha inesperada não coberta pelas anteriores (ex.: erro de
/// parsing de um DTO). Não deveria acontecer em produção com a API real.
final class UnknownFailure extends Failure {
  const UnknownFailure();
}
