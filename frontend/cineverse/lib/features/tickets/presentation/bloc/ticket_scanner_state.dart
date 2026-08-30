part of 'ticket_scanner_bloc.dart';

enum TicketScannerStatus { scanning, validating, result, error }

class TicketScannerState extends Equatable {
  const TicketScannerState({
    this.status = TicketScannerStatus.scanning,
    this.result,
    this.failure,
  });

  final TicketScannerStatus status;
  final TicketValidation? result;
  final Failure? failure;

  @override
  List<Object?> get props => [status, result, failure];
}
