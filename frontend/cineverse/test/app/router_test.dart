import 'package:cineverse/app/router.dart';
import 'package:cineverse/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeAuthRedirect', () {
    group('sessionStatus.unknown', () {
      test('fica na splash', () {
        expect(
          computeAuthRedirect(
            sessionStatus: SessionStatus.unknown,
            location: '/splash',
          ),
          isNull,
        );
      });

      test('qualquer outro caminho volta para a splash', () {
        expect(
          computeAuthRedirect(
            sessionStatus: SessionStatus.unknown,
            location: '/catalog',
          ),
          '/splash',
        );
        expect(
          computeAuthRedirect(
            sessionStatus: SessionStatus.unknown,
            location: '/login',
          ),
          '/splash',
        );
      });
    });

    group('sessionStatus.anonymous', () {
      test('sai da splash para o login — bug real corrigido (FE-07)', () {
        expect(
          computeAuthRedirect(
            sessionStatus: SessionStatus.anonymous,
            location: '/splash',
          ),
          '/login',
        );
      });

      test('fica em /login ou /register', () {
        expect(
          computeAuthRedirect(
            sessionStatus: SessionStatus.anonymous,
            location: '/login',
          ),
          isNull,
        );
        expect(
          computeAuthRedirect(
            sessionStatus: SessionStatus.anonymous,
            location: '/register',
          ),
          isNull,
        );
      });

      test(
        'rota protegida redireciona para /login a partir de qualquer ponto',
        () {
          expect(
            computeAuthRedirect(
              sessionStatus: SessionStatus.anonymous,
              location: '/catalog',
            ),
            '/login',
          );
          expect(
            computeAuthRedirect(
              sessionStatus: SessionStatus.anonymous,
              location: '/nearby/sessions/1/seats/checkout',
            ),
            '/login',
          );
        },
      );
    });

    group('sessionStatus.authenticated', () {
      test('sai da splash para o catálogo', () {
        expect(
          computeAuthRedirect(
            sessionStatus: SessionStatus.authenticated,
            location: '/splash',
          ),
          '/catalog',
        );
      });

      test('sai de /login ou /register para o catálogo', () {
        expect(
          computeAuthRedirect(
            sessionStatus: SessionStatus.authenticated,
            location: '/login',
          ),
          '/catalog',
        );
        expect(
          computeAuthRedirect(
            sessionStatus: SessionStatus.authenticated,
            location: '/register',
          ),
          '/catalog',
        );
      });

      test('fica na rota protegida atual', () {
        expect(
          computeAuthRedirect(
            sessionStatus: SessionStatus.authenticated,
            location: '/feed',
          ),
          isNull,
        );
      });
    });
  });
}
