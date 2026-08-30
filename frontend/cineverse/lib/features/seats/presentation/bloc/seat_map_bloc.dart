import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../../core/error/failure.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/ws/socket_factory.dart';
import '../../domain/entities/seat.dart';
import '../../domain/seat_grouping.dart';
import '../../domain/seats_repository.dart';

part 'seat_map_event.dart';
part 'seat_map_state.dart';

class SeatMapBloc extends Bloc<SeatMapEvent, SeatMapState> {
  SeatMapBloc(this._seatsRepository, this._socketFactory, this._tokenStorage)
    : super(const SeatMapState()) {
    on<SeatMapRequested>(_onRequested);
    on<SeatTapped>(_onTapped);
    on<SeatLockedReceived>(
      (event, emit) => _updateSeatStatus(event.seatId, SeatStatus.locked, emit),
    );
    on<SeatReleasedReceived>(
      (event, emit) =>
          _updateSeatStatus(event.seatId, SeatStatus.available, emit),
    );
    on<SeatSoldReceived>(
      (event, emit) => _updateSeatStatus(event.seatId, SeatStatus.sold, emit),
    );
  }

  final SeatsRepository _seatsRepository;
  final SocketFactory _socketFactory;
  final TokenStorage _tokenStorage;

  io.Socket? _socket;

  Future<void> _onRequested(
    SeatMapRequested event,
    Emitter<SeatMapState> emit,
  ) async {
    emit(
      state.copyWith(status: StateStatus.loading, sessionId: event.sessionId),
    );
    try {
      final seats = await _seatsRepository.fetchSeatMap(event.sessionId);
      emit(
        state.copyWith(
          status: StateStatus.success,
          seats: seats,
          groupedRows: groupSeatsByRow(seats),
        ),
      );
    } on Failure catch (failure) {
      emit(state.copyWith(status: StateStatus.failure, failure: failure));
      return;
    }

    if (_socket == null) {
      await _connectSocket();
    }
  }

  Future<void> _connectSocket() async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) return;

    final socket = _socketFactory.create(
      SocketNamespace.seats,
      accessToken: accessToken,
    );
    _socket = socket;

    socket.onConnect((_) {
      socket.emit('joinSession', {'sessionId': state.sessionId});
      // A reconexão pode ter perdido eventos — refaz o snapshot REST em vez
      // de confiar só no que chegou por WS.
      add(SeatMapRequested(state.sessionId));
    });
    socket.on(
      'seat_locked',
      (data) => add(SeatLockedReceived((data as Map)['seatId'] as int)),
    );
    socket.on(
      'seat_released',
      (data) => add(SeatReleasedReceived((data as Map)['seatId'] as int)),
    );
    socket.on(
      'seat_sold',
      (data) => add(SeatSoldReceived((data as Map)['seatId'] as int)),
    );
    socket.connect();
  }

  void _updateSeatStatus(
    int seatId,
    SeatStatus status,
    Emitter<SeatMapState> emit,
  ) {
    final updatedSeats = state.seats
        .map(
          (seat) =>
              seat.seatId == seatId ? seat.copyWith(status: status) : seat,
        )
        .toList();

    // Assento selecionado que foi tomado por outro sai da seleção — não
    // deixar seleção fantasma que só falharia na reserva.
    final updatedSelection = status == SeatStatus.available
        ? state.selectedSeatIds
        : (Set<int>.from(state.selectedSeatIds)..remove(seatId));

    emit(
      state.copyWith(
        seats: updatedSeats,
        groupedRows: groupSeatsByRow(updatedSeats),
        selectedSeatIds: updatedSelection,
      ),
    );
  }

  void _onTapped(SeatTapped event, Emitter<SeatMapState> emit) {
    final matches = state.seats.where((s) => s.seatId == event.seatId);
    if (matches.isEmpty || matches.first.status != SeatStatus.available) return;

    final updated = Set<int>.from(state.selectedSeatIds);
    if (!updated.add(event.seatId)) updated.remove(event.seatId);
    emit(state.copyWith(selectedSeatIds: updated));
  }

  @override
  Future<void> close() {
    _socket?.dispose();
    return super.close();
  }
}
