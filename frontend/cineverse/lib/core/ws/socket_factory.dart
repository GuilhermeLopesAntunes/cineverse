import 'package:socket_io_client/socket_io_client.dart' as io;

import '../auth/session_expiry_notifier.dart';
import '../config/app_config.dart';

enum SocketNamespace { chat, seats }

extension on SocketNamespace {
  String get path => switch (this) {
    SocketNamespace.chat => '/chat',
    SocketNamespace.seats => '/seats',
  };
}

/// Cria um socket Socket.io por tela, autenticado no handshake com o access
/// token — convenção do próprio Socket.io, lida pelo backend em
/// `ws-auth.middleware.ts`. Conexão é feita pelo chamador (`connect()`), para
/// o Bloc controlar o ciclo de vida junto com a tela.
class SocketFactory {
  SocketFactory(this._sessionExpiryNotifier);

  final SessionExpiryNotifier _sessionExpiryNotifier;

  io.Socket create(SocketNamespace namespace, {required String accessToken}) {
    final socket = io.io(
      '${AppConfig.apiBaseUrl}${namespace.path}',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .disableAutoConnect()
          .build(),
    );

    // Handshake rejeitado (token ausente/inválido/expirado) é o mesmo caso
    // de um 401 HTTP: sem renovação de token, a sessão acabou.
    socket.onConnectError((_) => _sessionExpiryNotifier.notify());

    return socket;
  }
}
