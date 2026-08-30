import 'package:flutter/material.dart';

/// Botão de ação primária do design escuro da marca — gradiente linear
/// roxo, um pouco maior que o [SecondaryButton] para marcar a ação
/// principal da tela.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  static const _gradient = LinearGradient(
    colors: [Color(0xFF6E37B3), Color(0xFF4E2086), Color(0xFF33145A)],
  );

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: _gradient,
        color: isEnabled ? null : Colors.black26,
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: const Color(0xFF6E37B3).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Opacity(
        opacity: isEnabled ? 1 : 0.5,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onPressed,
            child: Center(
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                child: IconTheme.merge(
                  data: const IconThemeData(color: Colors.white),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
