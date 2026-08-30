import 'package:equatable/equatable.dart';

/// `POST /orders/:orderId/payments` e `GET /orders/:orderId/payments`.
/// `status` é sempre `"pending" | "paid" | "failed"`. `copyPasteCode` só
/// existe na resposta de criação de um pagamento Pix — nunca no histórico.
class Payment extends Equatable {
  const Payment({
    required this.id,
    required this.orderId,
    required this.method,
    required this.providerRef,
    required this.status,
    required this.createdAt,
    this.copyPasteCode,
  });

  final int id;
  final int orderId;
  final String method;
  final String providerRef;
  final String status;
  final DateTime createdAt;
  final String? copyPasteCode;

  bool get isPaid => status == 'paid';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'pending';

  @override
  List<Object?> get props => [
    id,
    orderId,
    method,
    providerRef,
    status,
    createdAt,
    copyPasteCode,
  ];
}
