import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/widgets/app_error_view.dart';
import '../../domain/entities/ticket_validation.dart';
import '../bloc/ticket_scanner_bloc.dart';

/// Sem papel de funcionário no backend (nenhum conceito de auth de portaria
/// existe além do JWT comum) — rotulada como simulação de operação de
/// portaria, qualquer usuário autenticado pode abrir esta tela.
class TicketScannerPage extends StatelessWidget {
  const TicketScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leitor de ingresso')),
      body: BlocBuilder<TicketScannerBloc, TicketScannerState>(
        builder: (context, state) {
          return switch (state.status) {
            TicketScannerStatus.scanning ||
            TicketScannerStatus.validating => _ScannerView(
              isValidating: state.status == TicketScannerStatus.validating,
            ),
            TicketScannerStatus.result => _ResultView(result: state.result!),
            TicketScannerStatus.error => AppErrorView(
              failure: state.failure!,
              onRetry: () => context.read<TicketScannerBloc>().add(
                const ScanAgainRequested(),
              ),
            ),
          };
        },
      ),
    );
  }
}

class _ScannerView extends StatelessWidget {
  const _ScannerView({required this.isValidating});

  final bool isValidating;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              final value = barcode.rawValue;
              if (value != null) {
                context.read<TicketScannerBloc>().add(QrCodeDetected(value));
                break;
              }
            }
          },
        ),
        if (isValidating)
          const ColoredBox(
            color: Color(0x88000000),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final TicketValidation result;

  @override
  Widget build(BuildContext context) {
    final valid = result.valid;
    final reason = result.reason;

    final (icon, color, message) = switch ((valid, reason)) {
      (true, _) => (
        Icons.check_circle_outline,
        Colors.green,
        'Ingresso válido',
      ),
      (false, 'Ingresso já utilizado') => (
        Icons.history_toggle_off,
        Colors.orange,
        'Ingresso já utilizado',
      ),
      (false, _) => (
        Icons.cancel_outlined,
        Colors.red,
        reason ?? 'Ingresso inválido',
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.read<TicketScannerBloc>().add(
                const ScanAgainRequested(),
              ),
              child: const Text('Escanear novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
