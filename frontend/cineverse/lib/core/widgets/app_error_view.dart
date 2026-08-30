import 'package:flutter/material.dart';

import '../error/failure.dart';

/// Texto legível para o usuário final — 400/500 nunca são escritos para
/// usuário final; 409 é a única exceção, sua mensagem já vem pronta do
/// servidor (ver CLAUDE.md § Tratamento de erro).
String failureMessage(Failure failure) {
  return switch (failure) {
    NetworkFailure() => 'Sem conexão. Verifique sua internet.',
    UnauthorizedFailure() => 'Sua sessão expirou. Entre novamente.',
    ForbiddenFailure() => 'Você não tem acesso a este recurso.',
    NotFoundFailure() => 'Não encontrado.',
    ConflictFailure(:final message) => message,
    ValidationFailure(:final messages) => messages.join('\n'),
    ServerFailure() ||
    UnknownFailure() => 'Não foi possível concluir. Tente de novo.',
  };
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.failure, this.onRetry});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(failureMessage(failure), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Tentar de novo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
