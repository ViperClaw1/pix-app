import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/logger.dart';
import '../services/location_service.dart';
import '../services/permission_service.dart';

/// JavaScript Bridge: обработчики вызовов из WebView (openCamera, pickFile, getLocation, receivePushToken, openExternalLink)
/// и отправка событий в WebView (pushNotificationReceived, locationUpdated).
class JsBridge {
  JsBridge({
    required this.onPostMessage,
    required this.onEvaluateJavascript,
  });

  /// Отправить событие в WebView через postMessage / evaluateJavaScript.
  final void Function(String event, Map<String, dynamic> payload) onPostMessage;

  /// Выполнить JS в WebView (для инжекта после загрузки).
  final Future<void> Function(String js) onEvaluateJavascript;

  /// Имя handler'а, которое должно совпадать с вызовом из веб-приложения (например window.PixNative.openCamera).
  String get handlerName => AppConstants.jsBridgeHandlerName;

  /// Обработчик: открыть камеру и вернуть URL или base64 (по договорённости с веб-приложением).
  Future<Map<String, dynamic>> openCamera(Map<String, dynamic> args) async {
    final status = await PermissionService.instance.requestCamera();
    final granted = status == PermissionStatus.granted;
    if (!granted) {
      return {'success': false, 'error': 'permission_denied'};
    }
    try {
      final picker = ImagePicker();
      final source = args['source'] == 'gallery' ? ImageSource.gallery : ImageSource.camera;
      final XFile? file = await picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return {'success': false, 'error': 'cancelled'};
      final path = file.path;
      return {'success': true, 'path': path, 'name': file.name};
    } catch (e, st) {
      AppLogger.e('JsBridge', 'openCamera', e, st);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Обработчик: выбор файла (изображение или любой файл).
  Future<Map<String, dynamic>> pickFile(Map<String, dynamic> args) async {
    final granted = await PermissionService.instance.ensureFileUploadPermissions();
    if (!granted) {
      return {'success': false, 'error': 'permission_denied'};
    }
    try {
      final type = args['type'] as String?;
      FilePickerResult? result;
      if (type == 'image') {
        result = await FilePicker.platform.pickFiles(type: FileType.image);
      } else {
        result = await FilePicker.platform.pickFiles(allowMultiple: false);
      }
      if (result == null || result.files.isEmpty) {
        return {'success': false, 'error': 'cancelled'};
      }
      final file = result.files.single;
      return {
        'success': true,
        'path': file.path,
        'name': file.name,
        'size': file.size,
      };
    } catch (e, st) {
      AppLogger.e('JsBridge', 'pickFile', e, st);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Обработчик: получить текущую геолокацию.
  Future<Map<String, dynamic>> getLocation(Map<String, dynamic> args) async {
    final granted = await PermissionService.instance.ensureLocationPermission();
    if (!granted) {
      return {'success': false, 'error': 'permission_denied'};
    }
    final json = await LocationService.instance.getLocationJson();
    if (json == null) {
      return {'success': false, 'error': 'location_unavailable'};
    }
    return {'success': true, ...json};
  }

  /// Обработчик: веб-приложение регистрирует получение push-токена (no-op на нативной стороне, можно логировать).
  Future<Map<String, dynamic>> receivePushToken(Map<String, dynamic> args) async {
    final token = args['token'] as String?;
    if (token != null) {
      AppLogger.d('JsBridge', 'WebView received push token');
    }
    return {'success': true};
  }

  /// Обработчик: открыть внешнюю ссылку в браузере.
  Future<Map<String, dynamic>> openExternalLink(Map<String, dynamic> args) async {
    final url = args['url'] as String?;
    if (url == null || url.isEmpty) {
      return {'success': false, 'error': 'missing_url'};
    }
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return {'success': true};
      }
      return {'success': false, 'error': 'cannot_launch'};
    } catch (e, st) {
      AppLogger.e('JsBridge', 'openExternalLink', e, st);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Отправить в WebView событие pushNotificationReceived.
  void sendPushNotificationReceived(Map<String, dynamic> payload) {
    onPostMessage('pushNotificationReceived', payload);
  }

  /// Отправить в WebView событие locationUpdated.
  void sendLocationUpdated(Map<String, double> location) {
    onPostMessage('locationUpdated', location);
  }

  /// Отправить в WebView FCM токен (receivePushToken с нативной стороны).
  void sendPushToken(String token) {
    onPostMessage('pushToken', {'token': token});
  }

  /// Построить JS для вызова handler'а из веб-приложения.
  /// Ожидается, что веб-приложение подписывается на window.PixNative или аналогичный объект.
  String buildInjectScript() {
    return '''
(function() {
  window.$handlerName = window.$handlerName || {};
  window.$handlerName.openCamera = function(args) {
    return new Promise(function(resolve) {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('$handlerName', 'openCamera', args || {})
          .then(resolve).catch(function(e) { resolve({ success: false, error: String(e) }); });
      } else { resolve({ success: false, error: 'bridge_not_ready' }); }
    });
  };
  window.$handlerName.pickFile = function(args) {
    return new Promise(function(resolve) {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('$handlerName', 'pickFile', args || {})
          .then(resolve).catch(function(e) { resolve({ success: false, error: String(e) }); });
      } else { resolve({ success: false, error: 'bridge_not_ready' }); }
    });
  };
  window.$handlerName.getLocation = function(args) {
    return new Promise(function(resolve) {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('$handlerName', 'getLocation', args || {})
          .then(resolve).catch(function(e) { resolve({ success: false, error: String(e) }); });
      } else { resolve({ success: false, error: 'bridge_not_ready' }); }
    });
  };
  window.$handlerName.openExternalLink = function(args) {
    return new Promise(function(resolve) {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('$handlerName', 'openExternalLink', args || {})
          .then(resolve).catch(function(e) { resolve({ success: false, error: String(e) }); });
      } else { resolve({ success: false, error: 'bridge_not_ready' }); }
    });
  };
  window.dispatchEvent(new Event('PixNativeReady'));
})();
''';
  }

  /// Вызов из WebView: единый handler с методом и аргументами.
  Future<dynamic> handleCall(String method, dynamic args) async {
    final map = args is Map ? Map<String, dynamic>.from(args as Map) : <String, dynamic>{};
    switch (method) {
      case 'openCamera':
        return openCamera(map);
      case 'pickFile':
        return pickFile(map);
      case 'getLocation':
        return getLocation(map);
      case 'receivePushToken':
        return receivePushToken(map);
      case 'openExternalLink':
        return openExternalLink(map);
      default:
        return {'success': false, 'error': 'unknown_method'};
    }
  }
}
