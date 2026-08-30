/// `GET /sessions/:id/seats/map` devolve só `{ seatId, code, status }` — sem
/// linha, coluna ou geometria. `code` é uma string tipo "A1", "B12"
/// (convenção do backend em `Seat.code`); esta é a única regra do app que
/// separa isso em fileira + posição, com teste unitário próprio.
final _codePattern = RegExp(r'^([A-Za-z]+)(\d+)$');

/// Nome da fileira usada para código fora do padrão — a tela mostra esses
/// assentos numa fileira "outros" em vez de quebrar.
const otherRowLabel = 'Outros';

class SeatCode {
  const SeatCode._();

  /// Separa `"A12"` em `("A", 12)`. Código fora do padrão devolve
  /// `(otherRowLabel, null)` em vez de lançar.
  static (String row, int? position) parse(String code) {
    final match = _codePattern.firstMatch(code);
    if (match == null) return (otherRowLabel, null);
    return (match.group(1)!.toUpperCase(), int.parse(match.group(2)!));
  }
}
