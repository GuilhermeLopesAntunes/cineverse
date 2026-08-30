import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Scaffold compartilhado do login/registro: fundo escuro da marca, tema
/// forçado a dark (independente do tema do sistema) e sem AppBar — a logo e
/// o título dentro do [child] fazem o papel de cabeçalho.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: AppTheme.authBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: child,
          ),
        ),
      ),
    );
  }
}
