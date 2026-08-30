import '../../domain/entities/ticket_validation.dart';

/// Espelha `TicketValidationResult`: `{ valid, reason?, ticket? }`.
class TicketValidationModel {
  const TicketValidationModel({required this.valid, this.reason, this.ticket});

  factory TicketValidationModel.fromJson(Map<String, dynamic> json) {
    return TicketValidationModel(
      valid: json['valid'] as bool,
      reason: json['reason'] as String?,
      ticket: json['ticket'] != null
          ? TicketInfoModel.fromJson(json['ticket'] as Map<String, dynamic>)
          : null,
    );
  }

  final bool valid;
  final String? reason;
  final TicketInfoModel? ticket;

  TicketValidation toEntity() {
    return TicketValidation(
      valid: valid,
      reason: reason,
      ticket: ticket?.toEntity(),
    );
  }
}

/// Espelha `TicketResponse`: `{ id, orderItemId, qrCodePayload, status, usedAt, createdAt }`.
/// O app não usa `qrCodePayload` de volta — é o mesmo payload que já leu.
class TicketInfoModel {
  const TicketInfoModel({
    required this.id,
    required this.orderItemId,
    required this.status,
    required this.usedAt,
    required this.createdAt,
  });

  factory TicketInfoModel.fromJson(Map<String, dynamic> json) {
    return TicketInfoModel(
      id: json['id'] as int,
      orderItemId: json['orderItemId'] as int,
      status: json['status'] as String,
      usedAt: json['usedAt'] as String?,
      createdAt: json['createdAt'] as String,
    );
  }

  final int id;
  final int orderItemId;
  final String status;
  final String? usedAt;
  final String createdAt;

  TicketInfo toEntity() {
    return TicketInfo(
      id: id,
      orderItemId: orderItemId,
      status: status,
      usedAt: usedAt != null ? DateTime.parse(usedAt!).toLocal() : null,
      createdAt: DateTime.parse(createdAt).toLocal(),
    );
  }
}
