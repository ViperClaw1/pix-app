import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _initBridge();
    _subscribeToConnectivity();
    _subscribeToNotifications();
    NotificationService.instance.sendTokenToWebViewIfReady();
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

  Future<dynamic> _handleJsCall(List<dynamic> args) async {
    final method = args.isNotEmpty ? args[0] as String? : null;
    final arg = args.length > 1 ? args[1] : <String, dynamic>{};
    if (method == null) return {'success': false, 'error': 'missing_method'};
    return _jsBridge?.handleCall(method, arg) ??
        {'success': false, 'error': 'bridge_unavailable'};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
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
      ),
    );
  }
}
