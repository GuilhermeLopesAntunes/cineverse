import '../../domain/entities/payment.dart';

/// Espelha `PaymentResponse` (+ `copyPasteCode?` só na criação de um Pix):
/// `{ id, orderId, method, providerRef, status, createdAt, copyPasteCode? }`.
class PaymentModel {
  const PaymentModel({
    required this.id,
    required this.orderId,
    required this.method,
    required this.providerRef,
    required this.status,
    required this.createdAt,
    this.copyPasteCode,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as int,
      orderId: json['orderId'] as int,
      method: json['method'] as String,
      providerRef: json['providerRef'] as String,
      status: json['status'] as String,
      createdAt: json['createdAt'] as String,
      copyPasteCode: json['copyPasteCode'] as String?,
    );
  }

  final int id;
  final int orderId;
  final String method;
  final String providerRef;
  final String status;
  final String createdAt;
  final String? copyPasteCode;

  Payment toEntity() {
    return Payment(
      id: id,
      orderId: orderId,
      method: method,
      providerRef: providerRef,
      status: status,
      createdAt: DateTime.parse(createdAt).toLocal(),
      copyPasteCode: copyPasteCode,
    );
  }
}
