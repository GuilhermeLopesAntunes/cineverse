import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../payments/presentation/payment_args.dart';
import '../../../seats/domain/entities/seat.dart';
import '../../domain/entities/combo_item.dart';
import '../bloc/checkout_bloc.dart';
import '../checkout_args.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.args});

  final CheckoutArgs args;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  @override
  void initState() {
    super.initState();
    context.read<CheckoutBloc>().add(CheckoutStarted(widget.args));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: AppTheme.authBackground,
        body: SafeArea(
          child: BlocConsumer<CheckoutBloc, CheckoutState>(
            listener: (context, state) {
              if (state.status == CheckoutStatus.orderCreated) {
                context.pushReplacement(
                  '/nearby/sessions/${widget.args.sessionId}/seats/checkout/payment',
                  extra: PaymentArgs(
                    order: state.order!,
                    movieId: widget.args.movieId,
                    sessionDatetime: widget.args.sessionDatetime,
                    seats: widget.args.seats,
                    combos: state.combos,
                  ),
                );
              }
            },
            builder: (context, state) {
              return Column(
                children: [
                  const _Header(),
                  Expanded(
                    child: switch (state.status) {
                      CheckoutStatus.locking => const _CenterMessage(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Reservando seus assentos...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      CheckoutStatus.lockRejected => _MessagePanel(
                        icon: Icons.event_seat_outlined,
                        message:
                            state.lockRejectReason ??
                            'Não foi possível reservar os assentos.',
                        actionLabel: 'Voltar ao mapa',
                        onAction: () => context.pop(),
                      ),
                      CheckoutStatus.lockExpired => _MessagePanel(
                        icon: Icons.timer_off_outlined,
                        message:
                            'O tempo de reserva acabou. Escolha os assentos novamente.',
                        actionLabel: 'Voltar ao mapa',
                        onAction: () => context.pop(),
                      ),
                      CheckoutStatus.orderCreated => const _CenterMessage(
                        child: CircularProgressIndicator(),
                      ),
                      CheckoutStatus.ready ||
                      CheckoutStatus.submittingOrder ||
                      CheckoutStatus.failure => _CheckoutForm(state: state),
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'Finalizar compra',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(child: child);
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
            Icon(icon, size: 48, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            GradientButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({required this.remainingSeconds});

  final int remainingSeconds;

  String _format(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final isLow = remainingSeconds <= 60;
    final color = isLow ? const Color(0xFFE9666A) : const Color(0xFF6E37B3);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_outlined, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            'Tempo restante: ${_format(remainingSeconds)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutForm extends StatelessWidget {
  const _CheckoutForm({required this.state});

  final CheckoutState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        _CountdownBadge(remainingSeconds: state.remainingSeconds),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final seat in state.seats)
                _SeatComboCard(
                  seat: seat,
                  combos: state.combos,
                  selectedComboId: state.comboSelections[seat.seatId],
                  onComboChanged: (comboId) =>
                      context.read<CheckoutBloc>().add(
                        ComboSelected(
                          seatId: seat.seatId,
                          comboItemId: comboId,
                        ),
                      ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        if (state.failure != null)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Não foi possível confirmar o pedido. Tente de novo.',
              style: TextStyle(color: Color(0xFFE9666A)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total previsto',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    Formatters.money(state.previewTotalCents),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  onPressed: state.status == CheckoutStatus.submittingOrder
                      ? null
                      : () => context.read<CheckoutBloc>().add(
                          const OrderSubmitted(),
                        ),
                  child: state.status == CheckoutStatus.submittingOrder
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirmar pedido'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeatComboCard extends StatelessWidget {
  const _SeatComboCard({
    required this.seat,
    required this.combos,
    required this.selectedComboId,
    required this.onComboChanged,
  });

  final Seat seat;
  final List<ComboItem> combos;
  final int? selectedComboId;
  final ValueChanged<int?> onComboChanged;

  static const _shape = BorderRadius.only(
    topLeft: Radius.circular(16),
    bottomLeft: Radius.circular(16),
    bottomRight: Radius.circular(16),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: _shape,
        border: Border.all(color: const Color(0xFF6E37B3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_seat_outlined,
                color: Color(0xFFB98CF2),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Assento ${seat.code}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (combos.isNotEmpty) ...[
            const SizedBox(height: 10),
            // `isExpanded: true` é o que evita o overflow horizontal (nomes
            // de combo longos + preço não cabiam ao lado do rótulo do
            // assento numa única linha).
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: selectedComboId,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1330),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white54,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  hint: const Text(
                    'Sem combo',
                    style: TextStyle(color: Colors.white54),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Sem combo'),
                    ),
                    for (final combo in combos)
                      DropdownMenuItem<int?>(
                        value: combo.id,
                        child: Text(
                          '${combo.name} (${Formatters.money(combo.priceCents)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: onComboChanged,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
