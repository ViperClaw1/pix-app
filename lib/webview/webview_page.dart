import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../config/env.dart';
import '../core/constants.dart';
import '../core/logger.dart';
import '../services/notification_service.dart';
import '../ui/error_screen.dart';
import 'js_bridge.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage({
    super.key,
    required this.initialUrl,
    required this.channelId,
  });

  final String initialUrl;
  final String channelId;

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  final GlobalKey _webViewKey = GlobalKey();
  InAppWebViewController? _controller;
  JsBridge? _jsBridge;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isDarkTheme = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _applySystemUiTheme(dark: _isDarkTheme);
    _initBridge();
    _subscribeToConnectivity();
    _subscribeToNotifications();
    NotificationService.instance.sendTokenToWebViewIfReady();
  }

  void _applySystemUiTheme({required bool dark}) {
    final color = dark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final brightness = dark ? Brightness.dark : Brightness.light;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: color,
        statusBarIconBrightness: brightness,
        statusBarBrightness: brightness,
        systemNavigationBarColor: color,
        systemNavigationBarIconBrightness: brightness,
        systemNavigationBarDividerColor: color,
      ),
    );
  }

  void _initBridge() {
    _jsBridge = JsBridge(
      onPostMessage: _postMessageToWebView,
      onEvaluateJavascript: _evaluateJavascript,
    );
  }

  void _postMessageToWebView(String event, Map<String, dynamic> payload) {
    final payloadStr = _encodePayload(payload);
    final js = '''
      if (window.dispatchEvent && typeof CustomEvent !== 'undefined') {
        window.dispatchEvent(new CustomEvent('PixNativeEvent', { detail: { type: '$event', payload: $payloadStr } }));
      }
      true;
    ''';
    _evaluateJavascript(js);
  }

  String _encodePayload(Map<String, dynamic> payload) {
    final buf = StringBuffer('{');
    var first = true;
    for (final e in payload.entries) {
      if (!first) buf.write(',');
      first = false;
      final v = e.value;
      if (v is String) {
        buf.write(
            '"${e.key}":"${v.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"');
      } else if (v is num) {
        buf.write('"${e.key}":$v');
      } else if (v is Map) {
        buf.write('"${e.key}":${_encodePayload(Map<String, dynamic>.from(v))}');
      }
    }
    buf.write('}');
    return buf.toString();
  }

  Future<void> _evaluateJavascript(String js) async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.evaluateJavascript(source: js);
    } catch (e) {
      AppLogger.e('WebViewPage', 'evaluateJavascript', e, null);
    }
  }

  void _subscribeToConnectivity() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      final isOffline = result == ConnectivityResult.none;
      if (isOffline) {
        AppLogger.w('WebViewPage', 'Offline');
        _postMessageToWebView('connectivityChanged', {'online': false});
      } else {
        _postMessageToWebView('connectivityChanged', {'online': true});
      }
    });
  }

  void _subscribeToNotifications() {
    NotificationService.instance.onMessageForWebView = (payload) {
      _jsBridge?.sendPushNotificationReceived(payload);
    };
    NotificationService.instance.onTokenForWebView = (token) {
      _jsBridge?.sendPushToken(token);
    };
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    NotificationService.instance.onMessageForWebView = null;
    NotificationService.instance.onTokenForWebView = null;
    super.dispose();
  }

  Future<void> _syncThemeFromPage(InAppWebViewController controller) async {
    const detectThemeJs = r'''
      (function() {
        var meta = document.querySelector('meta[name="theme-color"]');
        var content = meta && meta.getAttribute('content');
        if (content) {
          var m = content.match(/^#?([0-9a-fA-F]{6})$/);
          if (m) {
            var r = parseInt(m[1].substr(0,2), 16), g = parseInt(m[1].substr(2,2), 16), b = parseInt(m[1].substr(4,2), 16);
            var luminance = (0.299*r + 0.587*g + 0.114*b) / 255;
            if (window.PixNative && window.PixNative.setTheme)
              window.PixNative.setTheme({ theme: luminance > 0.5 ? 'light' : 'dark' });
            return;
          }
        }
        var scheme = document.documentElement.getAttribute('data-theme') || document.documentElement.getAttribute('data-bs-theme');
        if (scheme === 'light' && window.PixNative && window.PixNative.setTheme)
          window.PixNative.setTheme({ theme: 'light' });
        else if (scheme === 'dark' && window.PixNative && window.PixNative.setTheme)
          window.PixNative.setTheme({ theme: 'dark' });
      })();
    ''';
    try {
      await controller.evaluateJavascript(source: detectThemeJs);
    } catch (_) {}
  }

  Future<dynamic> _handleJsCall(List<dynamic> args) async {
    final method = args.isNotEmpty ? args[0] as String? : null;
    final arg = args.length > 1 ? args[1] : <String, dynamic>{};
    if (method == null) return {'success': false, 'error': 'missing_method'};
    if (method == 'setTheme') {
      final theme = arg['theme'] as String?;
      final dark = theme != 'light';
      if (mounted) {
        setState(() => _isDarkTheme = dark);
        _applySystemUiTheme(dark: dark);
      }
      return {'success': true};
    }
    return _jsBridge?.handleCall(method, arg) ??
        {'success': false, 'error': 'bridge_unavailable'};
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _isDarkTheme ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    return Scaffold(
      backgroundColor: themeColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          InAppWebView(
              key: _webViewKey,
              initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                allowFileAccess: true,
                allowContentAccess: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                useOnLoadResource: true,
                useShouldInterceptRequest: true,
                cacheEnabled: true,
                clearCache: false,
                thirdPartyCookiesEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                useWideViewPort: true,
                loadWithOverviewMode: true,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
                controller.addJavaScriptHandler(
                  handlerName: AppConstants.jsBridgeHandlerName,
                  callback: _handleJsCall,
                );
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
              },
              onLoadStop: (controller, url) async {
                final js = _jsBridge?.buildInjectScript() ?? '';
                if (js.isNotEmpty) {
                  await controller.evaluateJavascript(source: js);
                }
                await _syncThemeFromPage(controller);
                if (mounted) {
                  setState(() => _isLoading = false);
                }
                NotificationService.instance.sendTokenToWebViewIfReady();
              },
              onReceivedError: (controller, request, error) {
                AppLogger.e('WebViewPage', 'onReceivedError',
                    '${error.type} ${error.description}', null);
                if (error.type == WebResourceErrorType.HOST_LOOKUP) {
                  setState(() => _errorMessage = 'Нет подключения к интернету');
                }
              },
              onReceivedHttpError: (controller, request, errorResponse) {
                final code = errorResponse.statusCode;
                if (code != null && code >= 400 && _isLoading) {
                  setState(() => _errorMessage = 'Ошибка загрузки ($code)');
                }
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;
                if (uri == null) return NavigationActionPolicy.ALLOW;
                final scheme = uri.scheme;
                if (scheme == 'http' || scheme == 'https') {
                  final host = uri.host;
                  if (host == 'pixapp.kz' ||
                      host.endsWith('.pixapp.kz') ||
                      Env.baseUrl.contains(host)) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  return NavigationActionPolicy.ALLOW;
                }
                if (scheme == 'tel' || scheme == 'mailto') {
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
              androidOnPermissionRequest:
                  (controller, origin, resources) async {
                return PermissionRequestResponse(
                    resources: resources,
                    action: PermissionRequestResponseAction.GRANT);
              },
            ),
          if (_isLoading) const LinearProgressIndicator(),
          if (_errorMessage != null)
            ErrorScreen(
              message: _errorMessage!,
              onRetry: () {
                setState(() => _errorMessage = null);
                _controller?.reload();
              },
            ),
        ],
      ),
    );
  }
}
