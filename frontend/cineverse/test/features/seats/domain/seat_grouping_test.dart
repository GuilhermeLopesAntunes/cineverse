import 'package:cineverse/core/utils/seat_code.dart';
import 'package:cineverse/features/seats/domain/entities/seat.dart';
import 'package:cineverse/features/seats/domain/seat_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

Seat _seat(int id, String code) =>
    Seat(seatId: id, code: code, status: SeatStatus.available);

void main() {
  group('groupSeatsByRow', () {
    test('lista vazia devolve mapa vazio', () {
      expect(groupSeatsByRow(const []), isEmpty);
    });

    test('agrupa por fileira e ordena por posição crescente', () {
      final grouped = groupSeatsByRow([
        _seat(1, 'B2'),
        _seat(2, 'A1'),
        _seat(3, 'B1'),
        _seat(4, 'A2'),
      ]);

      expect(grouped.keys.toList(), ['A', 'B']);
      expect(grouped['A']!.map((s) => s.code), ['A1', 'A2']);
      expect(grouped['B']!.map((s) => s.code), ['B1', 'B2']);
    });

    test(
      'código fora do padrão vai para a fileira "outros", sempre por último',
      () {
        final grouped = groupSeatsByRow([_seat(1, '???'), _seat(2, 'A1')]);

        expect(grouped.keys.toList(), ['A', otherRowLabel]);
        expect(grouped[otherRowLabel]!.single.code, '???');
      },
    );
  });
}
