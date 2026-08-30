import 'package:bloc_test/bloc_test.dart';
import 'package:cineverse/core/auth/session_expiry_notifier.dart';
import 'package:cineverse/core/error/failure.dart';
import 'package:cineverse/features/auth/domain/auth_repository.dart';
import 'package:cineverse/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository authRepository;
  late SessionExpiryNotifier sessionExpiryNotifier;

  setUp(() {
    authRepository = MockAuthRepository();
    sessionExpiryNotifier = SessionExpiryNotifier();
  });

  tearDown(() {
    sessionExpiryNotifier.dispose();
  });

  group('AuthSessionRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emite authenticated quando há sessão guardada',
      setUp: () => when(
        () => authRepository.hasStoredSession(),
      ).thenAnswer((_) async => true),
      build: () => AuthBloc(authRepository, sessionExpiryNotifier),
      act: (bloc) => bloc.add(const AuthSessionRequested()),
      expect: () => [
        const AuthState(sessionStatus: SessionStatus.authenticated),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emite anonymous quando não há sessão guardada',
      setUp: () => when(
        () => authRepository.hasStoredSession(),
      ).thenAnswer((_) async => false),
      build: () => AuthBloc(authRepository, sessionExpiryNotifier),
      act: (bloc) => bloc.add(const AuthSessionRequested()),
      expect: () => [const AuthState(sessionStatus: SessionStatus.anonymous)],
    );
  });

  group('AuthLoginRequested', () {
    blocTest<AuthBloc, AuthState>(
      'login com sucesso emite submitting depois authenticated/success',
      setUp: () => when(
        () => authRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {}),
      build: () => AuthBloc(authRepository, sessionExpiryNotifier),
      act: (bloc) => bloc.add(
        const AuthLoginRequested(email: 'a@a.com', password: 'password123'),
      ),
      expect: () => [
        const AuthState(actionStatus: AuthActionStatus.submitting),
        const AuthState(
          sessionStatus: SessionStatus.authenticated,
          actionStatus: AuthActionStatus.success,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'credencial inválida (401) emite failure com UnauthorizedFailure',
      setUp: () => when(
        () => authRepository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const UnauthorizedFailure()),
      build: () => AuthBloc(authRepository, sessionExpiryNotifier),
      act: (bloc) => bloc.add(
        const AuthLoginRequested(email: 'a@a.com', password: 'wrong'),
      ),
      expect: () => [
        const AuthState(actionStatus: AuthActionStatus.submitting),
        const AuthState(
          actionStatus: AuthActionStatus.failure,
          failure: UnauthorizedFailure(),
        ),
      ],
    );
  });

  group('AuthRegisterRequested', () {
    blocTest<AuthBloc, AuthState>(
      'e-mail duplicado (409) emite failure com ConflictFailure',
      setUp: () => when(
        () => authRepository.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          name: any(named: 'name'),
        ),
      ).thenThrow(const ConflictFailure('E-mail já cadastrado')),
      build: () => AuthBloc(authRepository, sessionExpiryNotifier),
      act: (bloc) => bloc.add(
        const AuthRegisterRequested(email: 'a@a.com', password: 'password123'),
      ),
      expect: () => [
        const AuthState(actionStatus: AuthActionStatus.submitting),
        const AuthState(
          actionStatus: AuthActionStatus.failure,
          failure: ConflictFailure('E-mail já cadastrado'),
        ),
      ],
    );
  });

  group('expiração de sessão', () {
    blocTest<AuthBloc, AuthState>(
      'SessionExpiryNotifier leva a sessão para anonymous',
      setUp: () => when(() => authRepository.logout()).thenAnswer((_) async {}),
      build: () => AuthBloc(authRepository, sessionExpiryNotifier),
      seed: () => const AuthState(sessionStatus: SessionStatus.authenticated),
      act: (bloc) => sessionExpiryNotifier.notify(),
      expect: () => [
        const AuthState(
          sessionStatus: SessionStatus.anonymous,
          actionStatus: AuthActionStatus.idle,
        ),
      ],
    );
  });
}
