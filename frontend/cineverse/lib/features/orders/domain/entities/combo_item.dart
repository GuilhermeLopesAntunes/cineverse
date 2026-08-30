import 'package:equatable/equatable.dart';

/// `GET /partners/:partnerId/combos` — sem descrição nem flag de
/// disponibilidade, só estes 4 campos.
class ComboItem extends Equatable {
  const ComboItem({
    required this.id,
    required this.partnerId,
    required this.name,
    required this.priceCents,
  });

  final int id;
  final int partnerId;
  final String name;
  final int priceCents;

  @override
  List<Object?> get props => [id, partnerId, name, priceCents];
}
