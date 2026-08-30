import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/ticket_validation.dart';
import '../../domain/tickets_repository.dart';

part 'ticket_scanner_event.dart';
part 'ticket_scanner_state.dart';

class TicketScannerBloc extends Bloc<TicketScannerEvent, TicketScannerState> {
  TicketScannerBloc(this._ticketsRepository)
    : super(const TicketScannerState()) {
    on<QrCodeDetected>(_onQrCodeDetected);
    on<ScanAgainRequested>(_onScanAgainRequested);
  }

  final TicketsRepository _ticketsRepository;

  Future<void> _onQrCodeDetected(
    QrCodeDetected event,
    Emitter<TicketScannerState> emit,
  ) async {
    // Ignora novas leituras enquanto já processa ou já mostra um resultado —
    // a câmera continua streaming frames com o mesmo código em quadro.
    if (state.status != TicketScannerStatus.scanning) return;

    emit(const TicketScannerState(status: TicketScannerStatus.validating));
    try {
      final result = await _ticketsRepository.validate(event.qrCodePayload);
      emit(
        TicketScannerState(status: TicketScannerStatus.result, result: result),
      );
    } on Failure catch (failure) {
      emit(
        TicketScannerState(status: TicketScannerStatus.error, failure: failure),
      );
    }
  }

  void _onScanAgainRequested(
    ScanAgainRequested event,
    Emitter<TicketScannerState> emit,
  ) {
    emit(const TicketScannerState());
  }
}
