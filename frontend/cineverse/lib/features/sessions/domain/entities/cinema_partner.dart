import 'package:equatable/equatable.dart';

/// `partner` de `GET /sessions/nearby` — único lugar de toda a API que
/// devolve o `id` do parceiro, necessário para listar combos no checkout.
class CinemaPartner extends Equatable {
  const CinemaPartner({
    required this.id,
    required this.name,
    required this.distanceKm,
  });

  final int id;
  final String name;
  final double distanceKm;

  @override
  List<Object?> get props => [id, name, distanceKm];
}
