part of 'seat_map_bloc.dart';

enum StateStatus { initial, loading, success, failure }

class SeatMapState extends Equatable {
  const SeatMapState({
    this.status = StateStatus.initial,
    this.sessionId = 0,
    this.seats = const [],
    this.groupedRows = const {},
    this.selectedSeatIds = const {},
    this.failure,
  });

  final StateStatus status;

  /// Vive no estado, não num campo tardio do Bloc — o socket reconecta e
  /// re-dispara `SeatMapRequested` com este mesmo id, e um campo `late
  /// final` não pode ser atribuído de novo (já quebrou em produção: ver
  /// CheckoutBloc, mesmo padrão de correção).
  final int sessionId;
  final List<Seat> seats;
  final Map<String, List<Seat>> groupedRows;
  final Set<int> selectedSeatIds;
  final Failure? failure;

  SeatMapState copyWith({
    StateStatus? status,
    int? sessionId,
    List<Seat>? seats,
    Map<String, List<Seat>>? groupedRows,
    Set<int>? selectedSeatIds,
    Failure? failure,
  }) {
    return SeatMapState(
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      seats: seats ?? this.seats,
      groupedRows: groupedRows ?? this.groupedRows,
      selectedSeatIds: selectedSeatIds ?? this.selectedSeatIds,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    sessionId,
    seats,
    groupedRows,
    selectedSeatIds,
    failure,
  ];
}
