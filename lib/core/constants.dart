/// Глобальные константы приложения.
class AppConstants {
  AppConstants._();

  /// Имя канала для нативных push-уведомлений (Android).
  static const String notificationChannelId = 'pix_app_notifications';
  static const String notificationChannelName = 'PIX уведомления';

  /// Таймаут загрузки WebView (секунды).
  static const int webViewLoadTimeoutSeconds = 30;

  /// Имя JS handler для bridge (должно совпадать с веб-приложением).
  static const String jsBridgeHandlerName = 'PixNative';

  /// SharedPreferences: однократный запрос разрешений при первом запуске.
  static const String prefsInitialPermissionsCompleted =
      'initial_permissions_completed';
}
