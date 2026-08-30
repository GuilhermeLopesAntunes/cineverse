import 'cinema_partner_model.dart';
import 'session_model.dart';

/// Espelha `GET /sessions/nearby` → `{ partner: {id,name,distanceKm}, sessions: [...] }`.
class NearbySessionsResponseModel {
  const NearbySessionsResponseModel({
    required this.partner,
    required this.sessions,
  });

  factory NearbySessionsResponseModel.fromJson(Map<String, dynamic> json) {
    return NearbySessionsResponseModel(
      partner: CinemaPartnerModel.fromJson(
        json['partner'] as Map<String, dynamic>,
      ),
      sessions: (json['sessions'] as List)
          .map((item) => SessionModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final CinemaPartnerModel partner;
  final List<SessionModel> sessions;
}
