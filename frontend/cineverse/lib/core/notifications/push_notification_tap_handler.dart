import 'package:go_router/go_router.dart';

/// Abre a sessão correspondente a uma notificação tocada — payload esperado
/// `{ "sessionId": "123" }`.
///
/// **Não está conectado a nenhum provedor de push nesta versão.** O backend
/// usa `MockPushSender`, que só grava no log do servidor (ver
/// ARQUITETURA_FRONTEND.md § 11, atrito 7): nenhuma notificação chega de
/// verdade a este app hoje, então esta função não tem, ainda, um callback
/// de `onMessageOpenedApp` para chamar. Ela existe para que a app fique
/// "preparada para receber" (FE-43): o dia em que um provedor real (ex.:
/// `firebase_messaging`) for integrado, o único ponto que muda é o
/// registro do listener — a navegação já está pronta aqui.
void handlePushNotificationTap(GoRouter router, Map<String, dynamic> data) {
  final sessionId = data['sessionId'];
  if (sessionId == null) return;
  router.push('/nearby/sessions/$sessionId/seats');
}
