import 'package:geolocator/geolocator.dart';

sealed class LocationResult {
  const LocationResult();
}

final class LocationCoordinates extends LocationResult {
  const LocationCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// Negada, mas ainda pode ser pedida de novo (mostrar explicação + botão).
final class LocationPermissionDenied extends LocationResult {
  const LocationPermissionDenied();
}

/// Negada permanentemente — só se resolve abrindo as configurações do app.
final class LocationPermissionDeniedForever extends LocationResult {
  const LocationPermissionDeniedForever();
}

/// GPS/localização desligado no dispositivo, independente de permissão.
final class LocationServiceDisabled extends LocationResult {
  const LocationServiceDisabled();
}

/// Envolve `geolocator` + `permission_handler`, tratando os três desfechos
/// de permissão que `GET /sessions/nearby` exige (RF-07).
class LocationService {
  Future<LocationResult> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return const LocationServiceDisabled();

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const LocationPermissionDenied();
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationPermissionDeniedForever();
    }

    final position = await Geolocator.getCurrentPosition();
    return LocationCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
}
