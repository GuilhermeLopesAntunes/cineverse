import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../domain/entities/combo_item.dart';
import '../../domain/entities/order.dart';
import '../../domain/orders_repository.dart';
import '../orders_api.dart';

class OrdersRepositoryImpl implements OrdersRepository {
  OrdersRepositoryImpl(this._ordersApi, this._failureMapper);

  final OrdersApi _ordersApi;
  final FailureMapper _failureMapper;

  @override
  Future<List<ComboItem>> fetchCombos(int partnerId) async {
    try {
      final models = await _ordersApi.fetchCombos(partnerId);
      return models.map((model) => model.toEntity()).toList();
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }

  @override
  Future<Order> createOrder({
    required int sessionId,
    required List<({int seatId, int? comboItemId})> items,
  }) async {
    try {
      final model = await _ordersApi.createOrder(
        sessionId: sessionId,
        items: items,
      );
      return model.toEntity();
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }
}
