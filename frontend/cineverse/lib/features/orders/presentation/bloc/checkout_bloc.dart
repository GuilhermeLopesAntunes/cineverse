import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../seats/domain/entities/seat.dart';
import '../../../seats/domain/seats_repository.dart';
import '../../domain/entities/combo_item.dart';
import '../../domain/entities/order.dart';
import '../../domain/orders_repository.dart';
import '../checkout_args.dart';

part 'checkout_event.dart';
part 'checkout_state.dart';

/// Mesmo valor do backend (`SEAT_LOCK_TTL_SECONDS`, default 300s) — não há
/// como descobrir o valor real do servidor por API, então o app assume o
/// default documentado.
const _lockSeconds = 300;

class CheckoutBloc extends Bloc<CheckoutEvent, CheckoutState> {
  CheckoutBloc(this._seatsRepository, this._ordersRepository)
    : super(const CheckoutState()) {
    on<CheckoutStarted>(_onStarted);
    on<ComboSelected>(_onComboSelected);
    on<CheckoutTimerTicked>(_onTimerTicked);
    on<OrderSubmitted>(_onOrderSubmitted);
  }

  final SeatsRepository _seatsRepository;
  final OrdersRepository _ordersRepository;

  Timer? _timer;

  Future<void> _onStarted(
    CheckoutStarted event,
    Emitter<CheckoutState> emit,
  ) async {
    final seatIds = event.args.seats.map((s) => s.seatId).toList();

    emit(
      CheckoutState(
        status: CheckoutStatus.locking,
        sessionId: event.args.sessionId,
        partnerId: event.args.partnerId,
        seats: event.args.seats,
        priceCentsPerSeat: event.args.priceCentsPerSeat,
      ),
    );

    try {
      final result = await _seatsRepository.lockSeats(
        sessionId: event.args.sessionId,
        seatIds: seatIds,
      );
      if (!result.success) {
        emit(
          state.copyWith(
            status: CheckoutStatus.lockRejected,
            lockRejectReason: result.reason,
          ),
        );
        return;
      }
    } on Failure catch (failure) {
      emit(state.copyWith(status: CheckoutStatus.failure, failure: failure));
      return;
    }

    emit(state.copyWith(remainingSeconds: _lockSeconds));
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(const CheckoutTimerTicked()),
    );

    try {
      final combos = await _ordersRepository.fetchCombos(event.args.partnerId);
      emit(state.copyWith(status: CheckoutStatus.ready, combos: combos));
    } on Failure {
      // Combos são complemento, não bloqueiam o checkout — segue sem opção
      // de combo em vez de travar quem já reservou o assento.
      emit(state.copyWith(status: CheckoutStatus.ready));
    }
  }

  void _onComboSelected(ComboSelected event, Emitter<CheckoutState> emit) {
    final updated = Map<int, int?>.from(state.comboSelections)
      ..[event.seatId] = event.comboItemId;
    emit(state.copyWith(comboSelections: updated));
  }

  Future<void> _onTimerTicked(
    CheckoutTimerTicked event,
    Emitter<CheckoutState> emit,
  ) async {
    if (state.remainingSeconds <= 1) {
      _timer?.cancel();
      unawaited(_releaseSeats());
      emit(
        state.copyWith(status: CheckoutStatus.lockExpired, remainingSeconds: 0),
      );
      return;
    }
    emit(state.copyWith(remainingSeconds: state.remainingSeconds - 1));
  }

  Future<void> _onOrderSubmitted(
    OrderSubmitted event,
    Emitter<CheckoutState> emit,
  ) async {
    emit(state.copyWith(status: CheckoutStatus.submittingOrder));
    final items = state.seats
        .map(
          (seat) => (
            seatId: seat.seatId,
            comboItemId: state.comboSelections[seat.seatId],
          ),
        )
        .toList();

    try {
      final order = await _ordersRepository.createOrder(
        sessionId: state.sessionId,
        items: items,
      );
      _timer?.cancel();
      emit(state.copyWith(status: CheckoutStatus.orderCreated, order: order));
    } on ConflictFailure {
      // Lock expirou entre o carregamento do checkout e a confirmação —
      // repetir a requisição sempre daria 409 de novo; a UI volta ao mapa.
      _timer?.cancel();
      emit(state.copyWith(status: CheckoutStatus.lockExpired));
    } on Failure catch (failure) {
      emit(state.copyWith(status: CheckoutStatus.ready, failure: failure));
    }
  }

  Future<void> _releaseSeats() {
    return _seatsRepository.releaseSeats(
      sessionId: state.sessionId,
      seatIds: state.seats.map((s) => s.seatId).toList(),
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    // Abandonar o checkout libera os assentos — não deixar preso até o TTL
    // enquanto outra pessoa tenta comprar. `lockExpired` já liberou sozinho
    // ao zerar o cronômetro, e `locking`/`orderCreated` nunca chegaram a
    // reter (ou já concluíram) a reserva.
    const statusesWithNothingToRelease = {
      CheckoutStatus.orderCreated,
      CheckoutStatus.locking,
      CheckoutStatus.lockExpired,
    };
    if (!statusesWithNothingToRelease.contains(state.status)) {
      unawaited(_releaseSeats());
    }
    return super.close();
  }
}
