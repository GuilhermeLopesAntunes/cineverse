import 'package:equatable/equatable.dart';

/// `POST /orders` — o valor oficial é sempre `totalAmountCents`, nunca o
/// calculado localmente para prévia.
class Order extends Equatable {
  const Order({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.status,
    required this.totalAmountCents,
    required this.createdAt,
    required this.items,
  });

  final int id;
  final int userId;
  final int sessionId;
  final String status;
  final int totalAmountCents;
  final DateTime createdAt;
  final List<OrderItem> items;

  @override
  List<Object?> get props => [
    id,
    userId,
    sessionId,
    status,
    totalAmountCents,
    createdAt,
    items,
  ];
}

class OrderItem extends Equatable {
  const OrderItem({required this.seatId, required this.comboItemId});

  final int seatId;
  final int? comboItemId;

  @override
  List<Object?> get props => [seatId, comboItemId];
}
