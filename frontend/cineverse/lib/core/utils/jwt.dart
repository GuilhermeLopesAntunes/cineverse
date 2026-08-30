import 'dart:convert';

/// Decodifica o payload de um JWT **sem validar assinatura** — uso
/// exclusivamente local, para ler `sub` (userId) e exibir/distinguir
/// mensagens próprias no chat. Nunca usar isso para decisão de segurança:
/// quem decide se o token é válido é o backend, em cada requisição.
Map<String, dynamic>? decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final payload = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(payload) as Map<String, dynamic>;
  } on FormatException {
    return null;
  }
}
