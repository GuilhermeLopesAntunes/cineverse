part of 'auth_bloc.dart';

enum SessionStatus { unknown, authenticated, anonymous }

enum AuthActionStatus { idle, submitting, success, failure }

/// Estado único do `AuthBloc`. Duas dimensões porque este Bloc é, ao mesmo
/// tempo, a sessão global do app (`sessionStatus`) e o estado do formulário
/// de login/cadastro (`actionStatus`) — é o único Bloc do catálogo com essa
/// dupla responsabilidade (ver ARQUITETURA_FRONTEND.md § 5).
class AuthState extends Equatable {
  const AuthState({
    this.sessionStatus = SessionStatus.unknown,
    this.actionStatus = AuthActionStatus.idle,
    this.failure,
  });

  final SessionStatus sessionStatus;
  final AuthActionStatus actionStatus;
  final Failure? failure;

  /// `failure` não usa `??`: passar `null` explicitamente é o jeito de
  /// limpar a falha ao sair do estado de erro (ex.: nova tentativa de login).
  AuthState copyWith({
    SessionStatus? sessionStatus,
    AuthActionStatus? actionStatus,
    Failure? failure,
  }) {
    return AuthState(
      sessionStatus: sessionStatus ?? this.sessionStatus,
      actionStatus: actionStatus ?? this.actionStatus,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [sessionStatus, actionStatus, failure];
}
