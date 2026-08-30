part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Disparado no bootstrap (splash) para restaurar sessão a partir do token
/// guardado.
final class AuthSessionRequested extends AuthEvent {
  const AuthSessionRequested();
}

final class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.email,
    required this.password,
    this.name,
  });

  final String email;
  final String password;
  final String? name;

  @override
  List<Object?> get props => [email, password, name];
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Vindo de fora do usuário: `401` HTTP (via [SessionExpiryNotifier]) ou
/// `connect_error` de qualquer socket. Nunca chamado diretamente por widget.
final class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}
