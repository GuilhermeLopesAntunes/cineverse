import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../orders/presentation/checkout_args.dart';
import '../../domain/entities/seat.dart';
import '../bloc/seat_map_bloc.dart';

const _kSeatFreeAsset = 'lib/app/assets/cine/Livre.svg';
const _kSeatOccupiedAsset = 'lib/app/assets/cine/Ocupado.svg';
const _kSeatSelectedAsset = 'lib/app/assets/cine/Selecionado.svg';
const _kScreenAsset = 'lib/app/assets/cine/telao.svg';

// Cor de "reservado" — não veio um ícone dedicado do design, então reusa o
// desenho do Ocupado.svg só trocando o tom (ColorFiltered) para não
// confundir com "vendido" (permanente) no mesmo vermelho.
const _lockedTint = Color(0xFFF2A93B);

// "Livre.svg" e "telao.svg" são desenhados num tom bem escuro (pensados
// para repousar sobre fundo claro) — direto no fundo quase preto da marca
// ficariam invisíveis. Em vez de colocar uma chapa branca atrás (quebrava o
// visual escuro do resto do app), recolore só esses dois para branco;
// Selecionado (verde) e Ocupado (vermelho) já têm contraste de sobra e
// ficam com a cor original do design.
const _lightTint = Colors.white;

class SeatMapArgs {
  const SeatMapArgs({
    required this.sessionId,
    required this.partnerId,
    required this.priceCents,
    required this.movieId,
    required this.sessionDatetime,
  });

  final int sessionId;
  final int partnerId;
  final int priceCents;

  /// Carregados adiante até a confirmação de compra (FE-39) — não existe
  /// como buscá-los de novo a partir do pedido, que só devolve `sessionId`.
  final int movieId;
  final DateTime sessionDatetime;
}

class SeatMapPage extends StatefulWidget {
  const SeatMapPage({super.key, required this.args});

  final SeatMapArgs args;

  @override
  State<SeatMapPage> createState() => _SeatMapPageState();
}

class _SeatMapPageState extends State<SeatMapPage> {
  @override
  void initState() {
    super.initState();
    context.read<SeatMapBloc>().add(SeatMapRequested(widget.args.sessionId));
  }

  String _statusLabel(SeatStatus status) => switch (status) {
    SeatStatus.available => 'disponível',
    SeatStatus.locked => 'reservado',
    SeatStatus.sold => 'vendido',
  };

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: AppTheme.authBackground,
        body: SafeArea(
          child: BlocBuilder<SeatMapBloc, SeatMapState>(
            builder: (context, state) {
              return Column(
                children: [
                  _Header(
                    subtitle: switch (state.status) {
                      StateStatus.success =>
                        '${state.selectedSeatIds.length} selecionado(s)',
                      _ => null,
                    },
                  ),
                  Expanded(child: _Content(state: state, statusLabel: _statusLabel)),
                  if (state.status == StateStatus.success)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: GradientButton(
                        onPressed: state.selectedSeatIds.isEmpty
                            ? null
                            : () => context.push(
                                '/nearby/sessions/${widget.args.sessionId}/seats/checkout',
                                extra: CheckoutArgs(
                                  sessionId: widget.args.sessionId,
                                  partnerId: widget.args.partnerId,
                                  priceCentsPerSeat: widget.args.priceCents,
                                  movieId: widget.args.movieId,
                                  sessionDatetime: widget.args.sessionDatetime,
                                  seats: state.seats
                                      .where(
                                        (s) => state.selectedSeatIds.contains(
                                          s.seatId,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                        child: Text(
                          'Reservar ${state.selectedSeatIds.length} assento(s)',
                        ),
                      ),
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
  const _Header({required this.subtitle});

  final String? subtitle;

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
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Escolha seus assentos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state, required this.statusLabel});

  final SeatMapState state;
  final String Function(SeatStatus) statusLabel;

  @override
  Widget build(BuildContext context) {
    if (state.status == StateStatus.initial ||
        state.status == StateStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == StateStatus.failure) {
      return AppErrorView(
        failure: state.failure!,
        onRetry: () =>
            context.read<SeatMapBloc>().add(SeatMapRequested(state.sessionId)),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const _Legend(),
        const SizedBox(height: 20),
        const _ScreenBanner(),
        const SizedBox(height: 28),
        for (final entry in state.groupedRows.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final seat in entry.value)
                        _SeatButton(
                          seat: seat,
                          isSelected: state.selectedSeatIds.contains(
                            seat.seatId,
                          ),
                          statusLabel: statusLabel(seat.status),
                          onTap: () => context.read<SeatMapBloc>().add(
                            SeatTapped(seat.seatId),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 8,
      children: [
        _LegendItem(
          icon: SizedBox(
            width: 28,
            height: 22,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(_lightTint, BlendMode.srcIn),
              child: SvgPicture.asset(_kSeatFreeAsset),
            ),
          ),
          label: 'Disponível',
        ),
        _LegendItem(
          icon: SizedBox(
            width: 28,
            height: 22,
            child: SvgPicture.asset(_kSeatSelectedAsset),
          ),
          label: 'Selecionado',
        ),
        _LegendItem(
          icon: SizedBox(
            width: 28,
            height: 22,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                _lockedTint,
                BlendMode.srcIn,
              ),
              child: SvgPicture.asset(_kSeatOccupiedAsset),
            ),
          ),
          label: 'Reservado',
        ),
        _LegendItem(
          icon: SizedBox(
            width: 28,
            height: 22,
            child: SvgPicture.asset(_kSeatOccupiedAsset),
          ),
          label: 'Vendido',
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _ScreenBanner extends StatelessWidget {
  const _ScreenBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6E37B3), width: 2),
      ),
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(_lightTint, BlendMode.srcIn),
        child: SvgPicture.asset(_kScreenAsset, height: 40),
      ),
    );
  }
}

class _SeatButton extends StatelessWidget {
  const _SeatButton({
    required this.seat,
    required this.isSelected,
    required this.statusLabel,
    required this.onTap,
  });

  final Seat seat;
  final bool isSelected;
  final String statusLabel;
  final VoidCallback onTap;

  Widget _icon() {
    if (isSelected) return SvgPicture.asset(_kSeatSelectedAsset);
    return switch (seat.status) {
      SeatStatus.available => ColorFiltered(
        colorFilter: const ColorFilter.mode(_lightTint, BlendMode.srcIn),
        child: SvgPicture.asset(_kSeatFreeAsset),
      ),
      SeatStatus.sold => SvgPicture.asset(_kSeatOccupiedAsset),
      SeatStatus.locked => ColorFiltered(
        colorFilter: const ColorFilter.mode(_lockedTint, BlendMode.srcIn),
        child: SvgPicture.asset(_kSeatOccupiedAsset),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isTappable = seat.status == SeatStatus.available;
    return Semantics(
      label: 'assento ${seat.code}, $statusLabel',
      button: isTappable,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isTappable ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 44,
            height: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 36, height: 28, child: _icon()),
                const SizedBox(height: 3),
                Text(
                  seat.code,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
