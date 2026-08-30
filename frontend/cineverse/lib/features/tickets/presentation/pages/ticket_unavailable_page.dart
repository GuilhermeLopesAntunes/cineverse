import 'package:flutter/material.dart';

/// `[BLOQUEADO-BACKEND]` — nenhuma rota devolve o `qrCodePayload` de um
/// ingresso comprado; `TicketsController` só expõe `POST /tickets/validate`.
/// O ingresso existe no banco e nunca sai de lá nesta versão. Proibido
/// gerar um QR falso no cliente para simular — ver BACKLOG_FRONTEND.md,
/// FE-40.
class TicketUnavailablePage extends StatelessWidget {
  const TicketUnavailablePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu ingresso')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.confirmation_number_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                'Ingresso gerado — exibição indisponível nesta versão',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'O QR do seu ingresso foi criado no servidor no momento da '
                'compra, mas a API atual não expõe uma rota para devolvê-lo '
                'ao aplicativo. Essa é uma limitação conhecida do backend '
                'desta versão, não um erro.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
