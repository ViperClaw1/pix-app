import 'package:permission_handler/permission_handler.dart';

import '../core/logger.dart';

/// Сервис запроса нативных разрешений: камера, хранилище, геолокация, уведомления.
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  /// Камера — для съёмки и загрузки фото (профиль, контент).
  Future<PermissionStatus> requestCamera() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return status;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      AppLogger.d('PermissionService', 'Camera: $result');
      return result;
    }
    return status;
  }

  /// Фото/медиа — для выбора изображений и файлов.
  Future<PermissionStatus> requestPhotos() async {
    final status = await Permission.photos.status;
    if (status.isGranted) return status;
    if (status.isDenied) {
      final result = await Permission.photos.request();
      AppLogger.d('PermissionService', 'Photos: $result');
      return result;
    }
    return status;
  }

  /// Хранилище (Android) — для выбора файлов.
  Future<PermissionStatus> requestStorage() async {
    final status = await Permission.storage.status;
    if (status.isGranted) return status;
    if (status.isDenied) {
      final result = await Permission.storage.request();
      AppLogger.d('PermissionService', 'Storage: $result');
      return result;
    }
    return status;
  }

  /// Точная геолокация — маршруты, ближайшие места, координаты в WebView.
  Future<PermissionStatus> requestLocation() async {
    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) return status;
    if (status.isDenied) {
      final result = await Permission.locationWhenInUse.request();
      AppLogger.d('PermissionService', 'Location: $result');
      return result;
    }
    return status;
  }

  /// Push-уведомления (Android 13+).
  Future<PermissionStatus> requestNotifications() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return status;
    if (status.isDenied) {
      final result = await Permission.notification.request();
      AppLogger.d('PermissionService', 'Notifications: $result');
      return result;
    }
    return status;
  }

  /// Запрос разрешений для загрузки файлов (камера + фото/хранилище).
  Future<bool> ensureFileUploadPermissions() async {
    await requestCamera();
    await requestPhotos();
    await requestStorage();
    final camera = await Permission.camera.status;
    final photos = await Permission.photos.status;
    final storage = await Permission.storage.status;
    return camera.isGranted && (photos.isGranted || storage.isGranted);
  }

  /// Запрос разрешения на геолокацию.
  Future<bool> ensureLocationPermission() async {
    final status = await requestLocation();
    return status.isGranted;
  }

  /// Открыть настройки приложения при постоянном отказе.
  Future<bool> openSettings() => openAppSettings();
}
