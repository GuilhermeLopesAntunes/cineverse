part of 'ticket_scanner_bloc.dart';

sealed class TicketScannerEvent extends Equatable {
  const TicketScannerEvent();

  @override
  List<Object?> get props => [];
}

/// Vindo da câmera (`mobile_scanner`) — o payload é enviado cru, sem
/// processamento local (RNF-12: a validação é toda do servidor).
final class QrCodeDetected extends TicketScannerEvent {
  const QrCodeDetected(this.qrCodePayload);

  final String qrCodePayload;

  @override
  List<Object?> get props => [qrCodePayload];
}

final class ScanAgainRequested extends TicketScannerEvent {
  const ScanAgainRequested();
}
