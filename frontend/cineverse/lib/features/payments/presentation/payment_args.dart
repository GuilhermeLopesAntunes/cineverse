import '../../orders/domain/entities/combo_item.dart';
import '../../orders/domain/entities/order.dart';
import '../../seats/domain/entities/seat.dart';

/// Tudo que a tela de pagamento precisa, mais o que ela repassa adiante
/// para a confirmação de compra (FE-39) — `seats`/`combos` resolvem código
/// de assento e nome do combo, que `Order` não traz.
class PaymentArgs {
  const PaymentArgs({
    required this.order,
    required this.movieId,
    required this.sessionDatetime,
    required this.seats,
    required this.combos,
  });

  final Order order;
  final int movieId;
  final DateTime sessionDatetime;
  final List<Seat> seats;
  final List<ComboItem> combos;
}
