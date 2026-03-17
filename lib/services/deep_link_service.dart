import '../core/logger.dart';

/// Deep Links: Universal Links (iOS), App Links (Android).
/// Обработка ссылок вида pixapp.kz/* для открытия в приложении.
///
/// Настройка:
/// - iOS: Associated Domains (applinks:pixapp.kz), apple-app-site-association на сервере.
/// - Android: intent-filter с android:autoVerify для https://pixapp.kz.
///
/// Инициализация и подписка на ссылки выполняются в платформенном коде
/// (getInitialLink / uriLinkStream). Здесь — интерфейс для передачи URL в WebView.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  /// URL, переданный при холодном старте через deep link.
  String? initialLink;

  /// Колбэк для навигации WebView на переданный deep link.
  void Function(String url)? onDeepLinkReceived;

  void setInitialLink(String? link) {
    initialLink = link;
    if (link != null) {
      AppLogger.d('DeepLinkService', 'Initial link: $link');
    }
  }

  void handleDeepLink(String url) {
    AppLogger.d('DeepLinkService', 'Deep link: $url');
    onDeepLinkReceived?.call(url);
  }
}
