import 'package:flutter/material.dart';

/// Campo de texto arredondado, preenchimento preto e borda branca — o
/// componente de input do design escuro da marca, usado no login, registro
/// e catálogo.
///
/// Quando [obscureText] é `true`, exibe um "olhinho" para alternar a
/// visibilidade da senha digitada.
class BrandedTextField extends StatefulWidget {
  const BrandedTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.helperText,
    this.prefixIcon,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.suffix,
    this.maxLines = 1,
    this.maxLength,
  });

  final TextEditingController controller;
  final String labelText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? helperText;
  final IconData? prefixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final int? maxLength;

  /// Sobrepõe o "olhinho" de senha quando informado — usado por campos que
  /// não são senha mas ainda precisam de um ícone à direita (ex.: limpar a
  /// busca).
  final Widget? suffix;

  @override
  State<BrandedTextField> createState() => _BrandedTextFieldState();
}

class _BrandedTextFieldState extends State<BrandedTextField> {
  static const _radius = BorderRadius.all(Radius.circular(28));

  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  OutlineInputBorder _border(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: _radius,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.obscureText && _obscured,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        labelText: widget.labelText,
        helperText: widget.helperText,
        labelStyle: const TextStyle(color: Colors.white70),
        helperStyle: const TextStyle(color: Colors.white54),
        errorStyle: const TextStyle(color: Colors.redAccent),
        counterStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.black,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(widget.prefixIcon, color: Colors.white70),
        suffixIcon: widget.suffix ??
            (widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white70,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null),
        border: _border(Colors.white, 1),
        enabledBorder: _border(Colors.white, 1),
        focusedBorder: _border(Colors.white, 1.5),
        errorBorder: _border(Colors.redAccent, 1),
        focusedErrorBorder: _border(Colors.redAccent, 1.5),
      ),
    );
  }
}
