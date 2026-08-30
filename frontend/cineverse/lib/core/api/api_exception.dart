/// Corpo de erro padrão do backend (`all-exceptions.filter.ts`):
/// ```json
/// { "statusCode": 409, "error": "Conflict", "message": "...", "requestId": "...",
///   "timestamp": "...", "path": "..." }
/// ```
///
/// Armadilha real: `message` chega como `String` **ou** `List<String>` —
/// array quando o `ValidationPipe` global rejeita o corpo. Este parser
/// normaliza os dois formatos em [messages]; tratar só como string produz
/// "[object Object]" na tela.
class ApiException {
  ApiException({
    required this.statusCode,
    required this.error,
    required this.messages,
    required this.requestId,
    required this.path,
  });

  factory ApiException.fromResponseData(int statusCode, dynamic data) {
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};

    final rawMessage = map['message'];
    final List<String> messages;
    if (rawMessage is List) {
      messages = rawMessage.map((e) => e.toString()).toList();
    } else if (rawMessage is String) {
      messages = [rawMessage];
    } else {
      messages = const [];
    }

    return ApiException(
      statusCode: map['statusCode'] is int
          ? map['statusCode'] as int
          : statusCode,
      error: map['error']?.toString() ?? '',
      messages: messages,
      requestId: map['requestId']?.toString(),
      path: map['path']?.toString(),
    );
  }

  final int statusCode;
  final String error;
  final List<String> messages;
  final String? requestId;
  final String? path;

  /// Junção legível das mensagens, para os casos (409) em que o app exibe
  /// o texto do servidor diretamente.
  String get messageText => messages.join('\n');
}
