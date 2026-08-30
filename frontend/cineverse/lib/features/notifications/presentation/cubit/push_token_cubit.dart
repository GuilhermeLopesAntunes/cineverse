import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/error/failure.dart';
import '../../domain/notifications_repository.dart';

part 'push_token_state.dart';

/// Bootstrap: chamado uma vez após o login estabelecer sessão (ver
/// `app.dart`), nunca por tela. Pede a permissão de notificação e registra
/// o token — a entrega de fato não é verificável nesta versão, porque o
/// backend usa `MockPushSender` (só grava no log do servidor).
class PushTokenCubit extends Cubit<PushTokenState> {
  PushTokenCubit(
    this._notificationsRepository, {
    Future<void> Function()? requestPermission,
  }) : _requestPermission =
           requestPermission ?? (() => Permission.notification.request()),
       super(const PushTokenState());

  final NotificationsRepository _notificationsRepository;
  final Future<void> Function() _requestPermission;
  bool _hasAttempted = false;

  Future<void> register() async {
    // Idempotente por natureza no servidor, mas evita uma chamada de rede
    // redundante a cada vez que o app observa a sessão como autenticada.
    if (_hasAttempted) return;
    _hasAttempted = true;

    emit(const PushTokenState(status: PushTokenStatus.registering));
    try {
      await _requestPermission();
      await _notificationsRepository.registerDeviceToken();
      emit(const PushTokenState(status: PushTokenStatus.success));
    } on Failure {
      // Falha ao registrar não é crítica para o uso do app — apenas fica
      // sem notificação (que já não é entregue de verdade nesta versão).
      emit(const PushTokenState(status: PushTokenStatus.failure));
    }
  }
}
