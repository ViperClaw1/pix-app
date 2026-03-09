import 'package:geolocator/geolocator.dart';

import '../core/logger.dart';

/// Сервис геолокации: получение координат для передачи в WebView.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Проверка доступности сервисов геолокации.
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Текущая позиция (одноразово). Используйте для getLocation в JS bridge.
  Future<Position?> getCurrentPosition() async {
    try {
      final enabled = await isLocationServiceEnabled();
      if (!enabled) {
        AppLogger.w('LocationService', 'Location services disabled');
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e, st) {
      AppLogger.e('LocationService', 'getCurrentPosition failed', e, st);
      return null;
    }
  }

  /// Координаты в формате для JS: { latitude, longitude }.
  Future<Map<String, double>?> getLocationJson() async {
    final position = await getCurrentPosition();
    if (position == null) return null;
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
    };
  }

  /// Стрим обновлений позиции (для locationUpdated в WebView).
  Stream<Position> get positionStream => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50,
        ),
      );
}
