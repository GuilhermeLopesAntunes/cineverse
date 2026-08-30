abstract class NotificationsRepository {
  /// Resolve a plataforma do dispositivo e registra o identificador de
  /// instalação. Não faz nada (nem chama a API) em plataformas fora de
  /// `ios`/`android` — o backend rejeita qualquer outro valor com `400`.
  Future<void> registerDeviceToken();
}
