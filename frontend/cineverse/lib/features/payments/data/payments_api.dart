import '../../../core/api/api_client.dart';
import 'models/payment_model.dart';

class PaymentsApi {
  PaymentsApi(this._apiClient);

  final ApiClient _apiClient;

  /// `token` é obrigatório para `apple_pay`/`google_pay`/`card`; ignorado
  /// (e não deve ser enviado) para `pix`. **Nenhum campo de cartão existe
  /// no DTO do backend** — enviar `cardNumber`/`cvv` resulta em `400`.
  Future<PaymentModel> createPayment({
    required int orderId,
    required String method,
    String? token,
  }) async {
    final response = await _apiClient.dio.post(
      '/orders/$orderId/payments',
      data: {'method': method, 'token': ?token},
    );
    return PaymentModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Array simples, sem paginação — é aqui que o app descobre que o Pix
  /// foi pago (o webhook é provedor→backend, nunca chega ao app).
  Future<List<PaymentModel>> fetchPayments(int orderId) async {
    final response = await _apiClient.dio.get('/orders/$orderId/payments');
    return (response.data as List)
        .map((item) => PaymentModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
