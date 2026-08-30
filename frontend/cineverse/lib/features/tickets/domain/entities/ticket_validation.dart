import 'package:equatable/equatable.dart';

/// `POST /tickets/validate` — **sempre `200`**, mesmo para QR forjado ou já
/// usado. `valid:false` é resultado de domínio, nunca erro de rede.
class TicketValidation extends Equatable {
  const TicketValidation({required this.valid, this.reason, this.ticket});

  final bool valid;
  final String? reason;
  final TicketInfo? ticket;

  @override
  List<Object?> get props => [valid, reason, ticket];
}

class TicketInfo extends Equatable {
  const TicketInfo({
    required this.id,
    required this.orderItemId,
    required this.status,
    required this.usedAt,
    required this.createdAt,
  });

  final int id;
  final int orderItemId;
  final String status;
  final DateTime? usedAt;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, orderItemId, status, usedAt, createdAt];
}
