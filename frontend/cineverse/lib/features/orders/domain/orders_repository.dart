import 'entities/combo_item.dart';
import 'entities/order.dart';

abstract class OrdersRepository {
  Future<List<ComboItem>> fetchCombos(int partnerId);

  /// `409` quando o lock expirou (assento não reservado por este usuário) —
  /// a UI volta ao mapa em vez de repetir a requisição.
  Future<Order> createOrder({
    required int sessionId,
    required List<({int seatId, int? comboItemId})> items,
  });
}
