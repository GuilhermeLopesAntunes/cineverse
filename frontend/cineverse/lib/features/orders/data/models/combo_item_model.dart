import '../../domain/entities/combo_item.dart';

/// Espelha `ComboItemResponse`: `{ id, partnerId, name, priceCents }`.
class ComboItemModel {
  const ComboItemModel({
    required this.id,
    required this.partnerId,
    required this.name,
    required this.priceCents,
  });

  factory ComboItemModel.fromJson(Map<String, dynamic> json) {
    return ComboItemModel(
      id: json['id'] as int,
      partnerId: json['partnerId'] as int,
      name: json['name'] as String,
      priceCents: json['priceCents'] as int,
    );
  }

  final int id;
  final int partnerId;
  final String name;
  final int priceCents;

  ComboItem toEntity() => ComboItem(
    id: id,
    partnerId: partnerId,
    name: name,
    priceCents: priceCents,
  );
}
