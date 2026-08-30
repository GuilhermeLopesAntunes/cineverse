/// Endereço do backend, injetado via `--dart-define=API_BASE_URL=...` —
/// nunca hardcoded (ver CLAUDE.md § Ambiente de desenvolvimento).
///
/// Valor típico por cenário:
/// - Emulador Android: `http://10.0.2.2:3000`
/// - Simulador iOS / desktop: `http://localhost:3000`
/// - Dispositivo físico: `http://<ip-da-máquina>:3000`
class AppConfig {
  const AppConfig._();

  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    assert(
      _apiBaseUrl.isNotEmpty,
      'API_BASE_URL não definido. Rode com '
      '--dart-define=API_BASE_URL=http://10.0.2.2:3000 (ou o endereço do seu ambiente).',
    );
    return _apiBaseUrl;
  }
}
