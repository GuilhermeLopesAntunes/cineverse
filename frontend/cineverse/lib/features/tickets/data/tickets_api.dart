import '../../../core/api/api_client.dart';
import 'models/ticket_validation_model.dart';

class TicketsApi {
  TicketsApi(this._apiClient);

  final ApiClient _apiClient;

  /// Sempre `200` — QR forjado, inexistente ou já usado é resultado normal
  /// de leitor, não erro de servidor.
  Future<TicketValidationModel> validate(String qrCodePayload) async {
    final response = await _apiClient.dio.post(
      '/tickets/validate',
      data: {'qrCodePayload': qrCodePayload},
    );
    return TicketValidationModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
