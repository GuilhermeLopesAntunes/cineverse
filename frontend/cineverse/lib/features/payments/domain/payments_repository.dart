import 'entities/payment.dart';

abstract class PaymentsRepository {
  /// `409` se o pedido já tiver pagamento (paid ou failed) — um pagamento
  /// por pedido, sem nova tentativa.
  Future<Payment> createPayment({
    required int orderId,
    required String method,
    String? token,
  });

  Future<List<Payment>> fetchPayments(int orderId);
}
