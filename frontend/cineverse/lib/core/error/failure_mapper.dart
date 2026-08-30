import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../api/api_exception.dart';
import 'failure.dart';

/// Único ponto que traduz uma [DioException] em [Failure]. Nenhuma outra
/// camada (repositório, Bloc) deve interpretar `DioException` ou status HTTP.
class FailureMapper {
  const FailureMapper();

  Failure map(DioException exception) {
    final response = exception.response;

    if (response == null) {
      return switch (exception.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError => const NetworkFailure(),
        _ => const UnknownFailure(),
      };
    }

    final statusCode = response.statusCode ?? 0;
    final apiException = ApiException.fromResponseData(
      statusCode,
      response.data,
    );
    _logRequestId(apiException);

    return switch (statusCode) {
      400 => ValidationFailure(apiException.messages),
      401 => const UnauthorizedFailure(),
      403 => const ForbiddenFailure(),
      404 => const NotFoundFailure(),
      409 => ConflictFailure(apiException.messageText),
      _ when statusCode >= 500 => const ServerFailure(),
      _ => const UnknownFailure(),
    };
  }

  /// O `requestId` do corpo de erro é o mesmo id que aparece no log
  /// estruturado do backend — é o que torna um bug reproduzível rastreável
  /// dos dois lados.
  void _logRequestId(ApiException apiException) {
    if (apiException.requestId == null) return;
    developer.log(
      'requestId=${apiException.requestId} path=${apiException.path} '
      'status=${apiException.statusCode}',
      name: 'api.error',
    );
  }
}
