import '../../domain/entities/cinema_partner.dart';

/// Espelha o objeto `partner` de `GET /sessions/nearby`: `{ id, name, distanceKm }`.
class CinemaPartnerModel {
  const CinemaPartnerModel({
    required this.id,
    required this.name,
    required this.distanceKm,
  });

  factory CinemaPartnerModel.fromJson(Map<String, dynamic> json) {
    return CinemaPartnerModel(
      id: json['id'] as int,
      name: json['name'] as String,
      distanceKm: (json['distanceKm'] as num).toDouble(),
    );
  }

  final int id;
  final String name;
  final double distanceKm;

  CinemaPartner toEntity() =>
      CinemaPartner(id: id, name: name, distanceKm: distanceKm);
}
