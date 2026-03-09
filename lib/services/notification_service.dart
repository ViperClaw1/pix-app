import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/logger.dart';

/// Push-уведомления: FCM, токен, пересылка в WebView.
///
/// Рекомендуемая архитектура: Firebase Cloud Messaging.
/// - Нативные push приходят через FCM.
/// - Токен отправляется в WebView (receivePushToken) для синхронизации с бэкендом.
/// - События push дублируются в WebView через postMessage (pushNotificationReceived).
/// Альтернативы: WebSocket bridge, REST polling, JS bridge — для синхронизации in-app уведомлений.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Колбэк для передачи payload в WebView (pushNotificationReceived).
  void Function(Map<String, dynamic> payload)? onMessageForWebView;

  /// Колбэк для передачи FCM токена в WebView (receivePushToken).
  void Function(String token)? onTokenForWebView;

  Future<void> initialize() async {
    await _requestPermission();
    _fcmToken = await FirebaseMessaging.instance.getToken();
    if (_fcmToken != null) {
      AppLogger.d('NotificationService', 'FCM token: ${_fcmToken!.substring(0, 20)}...');
      onTokenForWebView?.call(_fcmToken!);
    }

  FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
}

  Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    AppLogger.d('NotificationService', 'Permission: ${settings.authorizationStatus}');
  }

  void _onForegroundMessage(RemoteMessage message) {
    AppLogger.d('NotificationService', 'Foreground: ${message.notification?.title}');
    final payload = _messageToPayload(message);
    onMessageForWebView?.call(payload);
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    AppLogger.d('NotificationService', 'Opened: ${message.notification?.title}');
    final payload = _messageToPayload(message);
    onMessageForWebView?.call(payload);
  }

  Map<String, dynamic> _messageToPayload(RemoteMessage message) {
    return {
      'title': message.notification?.title,
      'body': message.notification?.body,
      'data': message.data,
    };
  }

  /// Вызвать после инициализации WebView, чтобы отправить токен в JS.
  void sendTokenToWebViewIfReady() {
    if (_fcmToken != null) {
      onTokenForWebView?.call(_fcmToken!);
    }
  }
}

/// Точка входа для background handler (топ-уровень). Регистрируется в main().
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  // Логирование в фоне может быть ограничено.
  // На Android канал задаётся в манифесте (default_notification_channel_id).
}
