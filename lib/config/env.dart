/// Конфигурация окружения через --dart-define.
///
/// Пример: flutter run --dart-define=ENV=production --dart-define=BASE_URL=https://pixapp.kz
class Env {
  Env._();

  static const String env = String.fromEnvironment(
    'ENV',
    defaultValue: 'production',
  );

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://pixapp.kz',
  );

  static bool get isDev => env == 'dev';
  static bool get isStaging => env == 'staging';
  static bool get isProduction => env == 'production';
}
