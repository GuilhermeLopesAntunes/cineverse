import 'package:cineverse/core/error/failure.dart';
import 'package:cineverse/core/error/failure_mapper.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final mapper = FailureMapper();
  final requestOptions = RequestOptions(path: '/orders');

  DioException dioExceptionWith({
    required int statusCode,
    required dynamic data,
  }) {
    return DioException(
      requestOptions: requestOptions,
      response: Response(
        requestOptions: requestOptions,
        statusCode: statusCode,
        data: data,
      ),
    );
  }

  group('FailureMapper', () {
    test(
      '400 com message como String vira ValidationFailure com uma mensagem',
      () {
        final exception = dioExceptionWith(
          statusCode: 400,
          data: {
            'statusCode': 400,
            'error': 'Bad Request',
            'message': 'email must be an email',
          },
        );

        final failure = mapper.map(exception);

        expect(failure, isA<ValidationFailure>());
        expect((failure as ValidationFailure).messages, [
          'email must be an email',
        ]);
      },
    );

    test(
      '400 com message como List<String> vira ValidationFailure com todas as mensagens',
      () {
        final exception = dioExceptionWith(
          statusCode: 400,
          data: {
            'statusCode': 400,
            'error': 'Bad Request',
            'message': [
              'email must be an email',
              'password must be longer than or equal to 8',
            ],
          },
        );

        final failure = mapper.map(exception);

        expect(failure, isA<ValidationFailure>());
        expect((failure as ValidationFailure).messages, [
          'email must be an email',
          'password must be longer than or equal to 8',
        ]);
      },
    );

    test('401 vira UnauthorizedFailure', () {
      final exception = dioExceptionWith(
        statusCode: 401,
        data: {
          'statusCode': 401,
          'error': 'Unauthorized',
          'message': 'Invalid credentials',
        },
      );

      expect(mapper.map(exception), isA<UnauthorizedFailure>());
    });

    test('403 vira ForbiddenFailure', () {
      final exception = dioExceptionWith(
        statusCode: 403,
        data: {'statusCode': 403, 'error': 'Forbidden', 'message': 'Forbidden'},
      );

      expect(mapper.map(exception), isA<ForbiddenFailure>());
    });

    test('404 vira NotFoundFailure', () {
      final exception = dioExceptionWith(
        statusCode: 404,
        data: {'statusCode': 404, 'error': 'Not Found', 'message': 'Not Found'},
      );

      expect(mapper.map(exception), isA<NotFoundFailure>());
    });

    test('409 vira ConflictFailure preservando a mensagem do servidor', () {
      const message =
          'Reserve o(s) assento(s) antes de finalizar a compra: 12, 13';
      final exception = dioExceptionWith(
        statusCode: 409,
        data: {'statusCode': 409, 'error': 'Conflict', 'message': message},
      );

      final failure = mapper.map(exception);

      expect(failure, isA<ConflictFailure>());
      expect((failure as ConflictFailure).message, message);
    });

    test('5xx vira ServerFailure', () {
      final exception = dioExceptionWith(
        statusCode: 500,
        data: {
          'statusCode': 500,
          'error': 'Internal Server Error',
          'message': 'Internal Server Error',
        },
      );

      expect(mapper.map(exception), isA<ServerFailure>());
    });

    test('timeout sem resposta vira NetworkFailure', () {
      final exception = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionTimeout,
      );

      expect(mapper.map(exception), isA<NetworkFailure>());
    });
  });
}
