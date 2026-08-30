import 'entities/ticket_validation.dart';

abstract class TicketsRepository {
  /// Nunca lança `Failure` para QR inválido/já usado — isso é
  /// `TicketValidation.valid == false`, resultado de domínio. Só lança para
  /// falha real de transporte (rede, 401, 5xx).
  Future<TicketValidation> validate(String qrCodePayload);
}
