import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/session_expiry_notifier.dart';
import '../../../../core/error/failure.dart';
import '../../domain/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Único Bloc global do app (ver ARQUITETURA_FRONTEND.md § 5). Instanciado
/// uma vez em `app.dart`, nunca por rota.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._authRepository, SessionExpiryNotifier sessionExpiryNotifier)
    : super(const AuthState()) {
    on<AuthSessionRequested>(_onSessionRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);

    _sessionExpirySubscription = sessionExpiryNotifier.onSessionExpired.listen(
      (_) => add(const AuthSessionExpired()),
    );
  }

  final AuthRepository _authRepository;
  late final StreamSubscription<void> _sessionExpirySubscription;

  Future<void> _onSessionRequested(
    AuthSessionRequested event,
    Emitter<AuthState> emit,
  ) async {
    final hasSession = await _authRepository.hasStoredSession();
    emit(
      state.copyWith(
        sessionStatus: hasSession
            ? SessionStatus.authenticated
            : SessionStatus.anonymous,
      ),
    );
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(actionStatus: AuthActionStatus.submitting));
    try {
      await _authRepository.login(email: event.email, password: event.password);
      emit(
        state.copyWith(
          sessionStatus: SessionStatus.authenticated,
          actionStatus: AuthActionStatus.success,
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          actionStatus: AuthActionStatus.failure,
          failure: failure,
        ),
      );
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(actionStatus: AuthActionStatus.submitting));
    try {
      await _authRepository.register(
        email: event.email,
        password: event.password,
        name: event.name,
      );
      emit(
        state.copyWith(
          sessionStatus: SessionStatus.authenticated,
          actionStatus: AuthActionStatus.success,
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          actionStatus: AuthActionStatus.failure,
          failure: failure,
        ),
      );
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(
      state.copyWith(
        sessionStatus: SessionStatus.anonymous,
        actionStatus: AuthActionStatus.idle,
      ),
    );
  }

  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(state.copyWith(sessionStatus: SessionStatus.anonymous));
  }

  @override
  Future<void> close() {
    _sessionExpirySubscription.cancel();
    return super.close();
  }
}
