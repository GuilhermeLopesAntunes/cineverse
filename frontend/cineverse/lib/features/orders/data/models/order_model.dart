import '../../domain/entities/order.dart';

/// Espelha `OrderResponse`: `{ id, userId, sessionId, status,
/// totalAmountCents, createdAt, items:[{seatId, comboItemId}] }`.
class OrderModel {
  const OrderModel({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.status,
    required this.totalAmountCents,
    required this.createdAt,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as int,
      userId: json['userId'] as int,
      sessionId: json['sessionId'] as int,
      status: json['status'] as String,
      totalAmountCents: json['totalAmountCents'] as int,
      createdAt: json['createdAt'] as String,
      items: (json['items'] as List)
          .map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final int id;
  final int userId;
  final int sessionId;
  final String status;
  final int totalAmountCents;
  final String createdAt;
  final List<OrderItemModel> items;

  Order toEntity() {
    return Order(
      id: id,
      userId: userId,
      sessionId: sessionId,
      status: status,
      totalAmountCents: totalAmountCents,
      createdAt: DateTime.parse(createdAt).toLocal(),
      items: items.map((item) => item.toEntity()).toList(),
    );
  }
}

class OrderItemModel {
  const OrderItemModel({required this.seatId, required this.comboItemId});

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      seatId: json['seatId'] as int,
      comboItemId: json['comboItemId'] as int?,
    );
  }

  final int seatId;
  final int? comboItemId;

  OrderItem toEntity() => OrderItem(seatId: seatId, comboItemId: comboItemId);
}
