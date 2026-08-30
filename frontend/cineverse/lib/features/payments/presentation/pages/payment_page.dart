import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../orders/domain/entities/order.dart';
import '../../domain/entities/payment.dart';
import '../bloc/payment_bloc.dart';
import '../payment_args.dart';

class PaymentPage extends StatelessWidget {
  const PaymentPage({super.key, required this.args});

  final PaymentArgs args;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamento')),
      body: BlocConsumer<PaymentBloc, PaymentState>(
        listener: (context, state) {
          if (state.status == PaymentStatus.paid) {
            context.pushReplacement(
              '/nearby/sessions/${args.order.sessionId}/seats/checkout/payment/success',
              extra: args,
            );
          }
        },
        builder: (context, state) {
          return switch (state.status) {
            PaymentStatus.selectingMethod => _MethodSelector(order: args.order),
            PaymentStatus.submitting => const Center(
              child: CircularProgressIndicator(),
            ),
            PaymentStatus.awaitingPixConfirmation => _PixPanel(
              payment: state.payment!,
            ),
            PaymentStatus.pollTimedOut => _MessagePanel(
              icon: Icons.hourglass_disabled_outlined,
              message:
                  'Ainda não conseguimos confirmar o pagamento. Verifique '
                  'novamente mais tarde em "Meus pedidos".',
              actionLabel: 'Voltar ao catálogo',
              onAction: () => context.go('/catalog'),
            ),
            PaymentStatus.paid => const Center(
              child: CircularProgressIndicator(),
            ),
            PaymentStatus.failed => _MessagePanel(
              icon: Icons.error_outline,
              message:
                  'Pagamento recusado. Este pedido não aceita uma nova '
                  'tentativa — inicie uma nova compra.',
              actionLabel: 'Iniciar nova compra',
              onAction: () => context.go('/catalog'),
            ),
            PaymentStatus.error => AppErrorView(failure: state.failure!),
          };
        },
      ),
    );
  }
}

class _MethodSelector extends StatelessWidget {
  const _MethodSelector({required this.order});

  final Order order;

  void _submit(BuildContext context, String method, {String? token}) {
    context.read<PaymentBloc>().add(
      PaymentSubmitted(method: method, token: token),
    );
  }

  @override
  Widget build(BuildContext context) {
    final simulatedToken = 'sim_${DateTime.now().millisecondsSinceEpoch}';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Total: ${Formatters.money(order.totalAmountCents)}'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Pagamento simulado nesta versão — nenhum valor real é cobrado. '
              'Carteira e cartão usam um identificador gerado no próprio '
              'aplicativo, sem formulário de número de cartão.',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _submit(context, 'pix'),
            icon: const Icon(Icons.qr_code),
            label: const Text('Pix'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                _submit(context, 'apple_pay', token: simulatedToken),
            icon: const Icon(Icons.apple),
            label: const Text('Apple Pay'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                _submit(context, 'google_pay', token: simulatedToken),
            icon: const Icon(Icons.g_mobiledata),
            label: const Text('Google Pay'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _submit(context, 'card', token: simulatedToken),
            icon: const Icon(Icons.credit_card),
            label: const Text('Cartão'),
          ),
        ],
      ),
    );
  }
}

class _PixPanel extends StatelessWidget {
  const _PixPanel({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final code = payment.copyPasteCode ?? '';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: code, size: 220),
            const SizedBox(height: 16),
            const Text(
              'Código simulado — não será reconhecido por um banco real.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Código copiado.')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar código'),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            const Text('Aguardando confirmação do pagamento...'),
          ],
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
