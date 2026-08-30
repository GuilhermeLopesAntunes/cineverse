import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../domain/entities/payment.dart';
import '../../domain/payments_repository.dart';
import '../payments_api.dart';

class PaymentsRepositoryImpl implements PaymentsRepository {
  PaymentsRepositoryImpl(this._paymentsApi, this._failureMapper);

  final PaymentsApi _paymentsApi;
  final FailureMapper _failureMapper;

  @override
  Future<Payment> createPayment({
    required int orderId,
    required String method,
    String? token,
  }) async {
    try {
      final model = await _paymentsApi.createPayment(
        orderId: orderId,
        method: method,
        token: token,
      );
      return model.toEntity();
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }

  @override
  Future<List<Payment>> fetchPayments(int orderId) async {
    try {
      final models = await _paymentsApi.fetchPayments(orderId);
      return models.map((model) => model.toEntity()).toList();
    } on DioException catch (e) {
      throw _failureMapper.map(e);
    }
  }
}
