import 'package:cineverse/core/utils/seat_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeatCode.parse', () {
    test('código normal separa fileira e posição', () {
      expect(SeatCode.parse('A1'), ('A', 1));
      expect(SeatCode.parse('B12'), ('B', 12));
    });

    test('fileira de duas letras', () {
      expect(SeatCode.parse('AA1'), ('AA', 1));
    });

    test('normaliza fileira para maiúscula', () {
      expect(SeatCode.parse('a1'), ('A', 1));
    });

    test('código fora do padrão vai para a fileira "outros"', () {
      expect(SeatCode.parse('???'), (otherRowLabel, null));
      expect(SeatCode.parse(''), (otherRowLabel, null));
      expect(SeatCode.parse('12A'), (otherRowLabel, null));
    });
  });
}
