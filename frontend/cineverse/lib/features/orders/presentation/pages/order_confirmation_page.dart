import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/formatters.dart';
import '../../../payments/presentation/payment_args.dart';

/// Resumo final: filme, sessão, assentos (código, não id) e combos, com o
/// total oficial do servidor (`order.totalAmountCents`). Nada aqui dispara
/// requisição nova — tudo já veio pelo `extra` da navegação (mapa de
/// assentos → checkout → pagamento).
class OrderConfirmationPage extends StatelessWidget {
  const OrderConfirmationPage({super.key, required this.args});

  final PaymentArgs args;

  @override
  Widget build(BuildContext context) {
    final comboNameById = {
      for (final combo in args.combos) combo.id: combo.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compra confirmada'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Pedido #${args.order.id} confirmado',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Filme #${args.movieId}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(Formatters.dateTime(args.sessionDatetime)),
          const SizedBox(height: 16),
          Text('Assentos', style: Theme.of(context).textTheme.titleSmall),
          for (final item in args.order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${_seatCode(item.seatId)}'
                '${item.comboItemId != null ? ' — ${comboNameById[item.comboItemId] ?? 'combo'}' : ''}',
              ),
            ),
          const Divider(height: 32),
          Text(
            'Total: ${Formatters.money(args.order.totalAmountCents)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => context.push('/ticket'),
            child: const Text('Ver meu ingresso'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.go('/catalog'),
            child: const Text('Voltar ao catálogo'),
          ),
        ],
      ),
    );
  }

  String _seatCode(int seatId) {
    final matches = args.seats.where((s) => s.seatId == seatId);
    return matches.isEmpty
        ? 'Assento #$seatId'
        : 'Assento ${matches.first.code}';
  }
}
