import 'dart:async';

/// Ponte entre a infraestrutura (interceptor HTTP, `connect_error` de socket)
/// e o `AuthBloc` (FE-09), que ainda não existe neste ponto do bootstrap.
///
/// Nem o interceptor nem o `SocketFactory` conhecem o `AuthBloc` diretamente
/// — ambos apenas [notify]. O `AuthBloc` se inscreve em [onSessionExpired] e
/// emite o estado anônimo, redirecionando o app via `go_router`.
class SessionExpiryNotifier {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get onSessionExpired => _controller.stream;

  void notify() => _controller.add(null);

  void dispose() => _controller.close();
}
