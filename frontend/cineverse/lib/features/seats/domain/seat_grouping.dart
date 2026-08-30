import '../../../core/utils/seat_code.dart';
import 'entities/seat.dart';

/// Agrupa por fileira e ordena: fileiras em ordem alfabética (com
/// [otherRowLabel] sempre por último), assentos dentro da fileira por
/// posição crescente. Único lugar do app que faz essa junção — a tela só
/// itera o resultado.
Map<String, List<Seat>> groupSeatsByRow(List<Seat> seats) {
  final groups = <String, List<Seat>>{};
  for (final seat in seats) {
    final (row, _) = SeatCode.parse(seat.code);
    groups.putIfAbsent(row, () => []).add(seat);
  }

  for (final row in groups.keys) {
    groups[row]!.sort((a, b) {
      final (_, posA) = SeatCode.parse(a.code);
      final (_, posB) = SeatCode.parse(b.code);
      if (posA == null && posB == null) return a.code.compareTo(b.code);
      if (posA == null) return 1;
      if (posB == null) return -1;
      return posA.compareTo(posB);
    });
  }

  final sortedKeys = groups.keys.toList()
    ..sort((a, b) {
      if (a == otherRowLabel) return 1;
      if (b == otherRowLabel) return -1;
      return a.compareTo(b);
    });

  return {for (final key in sortedKeys) key: groups[key]!};
}
