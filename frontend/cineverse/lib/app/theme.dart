import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  /// Fundo das telas de login/registro: uma versão bem mais escura de
  /// #1A1F50, quase preta, mas mantendo um resquício da tonalidade azulada
  /// da marca em vez de um preto puro.
  static const authBackground = Color(0xFF07081A);

  static ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    ),
  );
}
