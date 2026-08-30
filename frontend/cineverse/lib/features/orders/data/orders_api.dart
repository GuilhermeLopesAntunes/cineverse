import '../../../core/api/api_client.dart';
import 'models/combo_item_model.dart';
import 'models/order_model.dart';

class OrdersApi {
  OrdersApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ComboItemModel>> fetchCombos(int partnerId) async {
    final response = await _apiClient.dio.get('/partners/$partnerId/combos');
    return (response.data as List)
        .map((item) => ComboItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<OrderModel> createOrder({
    required int sessionId,
    required List<({int seatId, int? comboItemId})> items,
  }) async {
    final response = await _apiClient.dio.post(
      '/orders',
      data: {
        'sessionId': sessionId,
        'items': [
          for (final item in items)
            {
              'seatId': item.seatId,
              if (item.comboItemId != null) 'comboItemId': item.comboItemId,
            },
        ],
      },
    );
    return OrderModel.fromJson(response.data as Map<String, dynamic>);
  }
}
