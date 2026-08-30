import 'package:flutter/material.dart';

/// Botão de ação secundária do design escuro da marca — preto sólido, menor
/// que o [GradientButton], usado para ações de "voltar"/cancelar.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        child: child,
      ),
    );
  }
}
