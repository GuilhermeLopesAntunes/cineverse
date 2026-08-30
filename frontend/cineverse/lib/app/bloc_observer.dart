import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Log de transição de estado em debug — toda mudança de estado passa pelo
/// funil de eventos (ver CLAUDE.md § WebSocket), então isso também cobre
/// eventos vindos de WS e de timer.
class AppBlocObserver extends BlocObserver {
  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    super.onTransition(bloc, transition);
    if (kDebugMode) {
      developer.log('${bloc.runtimeType} $transition', name: 'bloc');
    }
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      developer.log(
        '${bloc.runtimeType} error',
        name: 'bloc',
        error: error,
        stackTrace: stackTrace,
      );
    }
    super.onError(bloc, error, stackTrace);
  }
}
