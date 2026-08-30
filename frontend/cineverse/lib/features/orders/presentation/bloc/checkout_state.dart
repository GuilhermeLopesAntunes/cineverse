part of 'checkout_bloc.dart';

enum CheckoutStatus {
  locking,
  lockRejected,
  ready,
  submittingOrder,
  orderCreated,
  lockExpired,
  failure,
}

class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.locking,
    this.sessionId = 0,
    this.partnerId = 0,
    this.seats = const [],
    this.priceCentsPerSeat = 0,
    this.remainingSeconds = 0,
    this.combos = const [],
    this.comboSelections = const {},
    this.failure,
    this.lockRejectReason,
    this.order,
  });

  final CheckoutStatus status;
  final int sessionId;
  final int partnerId;
  final List<Seat> seats;
  final int priceCentsPerSeat;
  final int remainingSeconds;
  final List<ComboItem> combos;

  /// `seatId` → `comboItemId?` escolhido para aquele assento.
  final Map<int, int?> comboSelections;
  final Failure? failure;
  final String? lockRejectReason;
  final Order? order;

  /// Prévia calculada localmente — só para exibição. O valor oficial é
  /// sempre `order.totalAmountCents`, devolvido pelo servidor.
  int get previewTotalCents {
    final comboPriceById = {
      for (final combo in combos) combo.id: combo.priceCents,
    };
    final comboTotal = comboSelections.values.whereType<int>().fold(
      0,
      (sum, comboId) => sum + (comboPriceById[comboId] ?? 0),
    );
    return (priceCentsPerSeat * seats.length) + comboTotal;
  }

  CheckoutState copyWith({
    CheckoutStatus? status,
    int? sessionId,
    int? partnerId,
    List<Seat>? seats,
    int? priceCentsPerSeat,
    int? remainingSeconds,
    List<ComboItem>? combos,
    Map<int, int?>? comboSelections,
    Failure? failure,
    String? lockRejectReason,
    Order? order,
  }) {
    return CheckoutState(
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      partnerId: partnerId ?? this.partnerId,
      seats: seats ?? this.seats,
      priceCentsPerSeat: priceCentsPerSeat ?? this.priceCentsPerSeat,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      combos: combos ?? this.combos,
      comboSelections: comboSelections ?? this.comboSelections,
      failure: failure,
      lockRejectReason: lockRejectReason,
      order: order ?? this.order,
    );
  }

  @override
  List<Object?> get props => [
    status,
    sessionId,
    partnerId,
    seats,
    priceCentsPerSeat,
    remainingSeconds,
    combos,
    comboSelections,
    failure,
    lockRejectReason,
    order,
  ];
}
