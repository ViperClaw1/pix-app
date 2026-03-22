import 'dart:async';
import 'dart:io' show Platform;

import 'package:android_intent_plus/android_intent.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/env.dart';
import '../core/constants.dart';
import '../core/logger.dart';
import '../services/deep_link_service.dart';
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
  StreamSubscription<Uri>? _appLinksSubscription;
  bool _isDarkTheme = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _applySystemUiTheme(dark: _isDarkTheme);
    _initBridge();
    _subscribeToConnectivity();
    _subscribeToNotifications();
    _subscribeToAppLinks();
    NotificationService.instance.sendTokenToWebViewIfReady();
  }

  /// Theme colors for status bar / home-indicator areas (match web light/dark).
  static Color _themeSurfaceColor(bool dark) =>
      dark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

  /// Per-platform overlay style. iOS needs explicit [statusBarIconBrightness]
  /// (same semantics as Android); [statusBarBrightness] alone is unreliable on
  /// recent iOS + edge-to-edge. [systemStatusBarContrastEnforced] avoids iOS
  /// forcing the wrong icon contrast over transparent bars.
  SystemUiOverlayStyle _systemUiOverlayStyleForTheme(bool dark) {
    final color = _themeSurfaceColor(dark);
    final iconBrightness = dark ? Brightness.light : Brightness.dark;
    if (Platform.isIOS) {
      return SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemStatusBarContrastEnforced: false,
      );
    }
    return SystemUiOverlayStyle(
      statusBarColor: color,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: color,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: color,
    );
  }

  void _applySystemUiTheme({required bool dark}) {
    SystemChrome.setSystemUIOverlayStyle(_systemUiOverlayStyleForTheme(dark));
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
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
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

  void _subscribeToAppLinks() {
    try {
      final appLinks = AppLinks();
      _appLinksSubscription = appLinks.uriLinkStream.listen((Uri uri) {
        DeepLinkService.instance.handleDeepLink(uri.toString());
      });
    } catch (e) {
      AppLogger.e('WebViewPage', '_subscribeToAppLinks', e, null);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _appLinksSubscription?.cancel();
    NotificationService.instance.onMessageForWebView = null;
    NotificationService.instance.onTokenForWebView = null;
    DeepLinkService.instance.onDeepLinkReceived = null;
    super.dispose();
  }

  /// Returns true if the URI is part of an OAuth flow that must open in a secure browser.
  ///
  /// Important: the *entire* OAuth flow must stay in the same browser context.
  /// If we open only the Google page externally but keep the provider (e.g. Lovable) in WebView,
  /// the provider's state/cookies won't be present in the external browser and the callback will fail.
  bool _shouldOpenOAuthInSecureBrowser(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    // Lovable OAuth broker (seen in your screenshot).
    if (host == 'oauth.lovable.app') return true;

    if (host == 'accounts.google.com') return true;
    if (host == 'www.google.com' || host == 'google.com') {
      return path.startsWith('/o/oauth2') ||
          path.startsWith('/signin/') ||
          path.startsWith('/accounts/') ||
          path.contains('accounts.');
    }
    return false;
  }

  /// Extracts S.browser_fallback_url from an Android intent URL string.
  String? _parseIntentFallbackUrl(String intentUrl) {
    final match =
        RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(intentUrl);
    if (match == null) return null;
    try {
      return Uri.decodeComponent(match.group(1)!);
    } catch (_) {
      return null;
    }
  }

  /// Opens the URL in Chrome Custom Tabs (Android) / SFSafariViewController (iOS).
  Future<void> _openInChromeSafariBrowser(Uri uri) async {
    try {
      final browser = ChromeSafariBrowser();
      await browser.open(
        url: WebUri(uri.toString()),
        options: ChromeSafariBrowserClassOptions(
          android: AndroidChromeCustomTabsOptions(
              shareState: CustomTabsShareState.SHARE_STATE_OFF),
          ios: IOSSafariOptions(barCollapsingEnabled: true),
        ),
      );
    } catch (e) {
      AppLogger.e('WebViewPage', '_openInChromeSafariBrowser', e, null);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e2) {
        AppLogger.e('WebViewPage', 'launchUrl fallback', e2, null);
      }
    }
  }

  /// Launches Android intent or fallback URL; on iOS launches fallback only.
  Future<void> _launchIntentOrFallback(
      String intentUrl, String? fallbackUrl) async {
    final fallback = fallbackUrl ?? _parseIntentFallbackUrl(intentUrl);
    if (Platform.isAndroid) {
      try {
        final intent = AndroidIntent(data: intentUrl);
        await intent.launch();
        return;
      } catch (e) {
        AppLogger.d('WebViewPage', 'AndroidIntent failed, using fallback', e);
      }
    }
    if (fallback != null && fallback.startsWith('http')) {
      try {
        await launchUrl(Uri.parse(fallback),
            mode: LaunchMode.externalApplication);
      } catch (e) {
        AppLogger.e('WebViewPage', '_launchIntentOrFallback', e, null);
      }
    }
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
        if (Platform.isIOS) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _applySystemUiTheme(dark: _isDarkTheme);
          });
        }
      }
      return {'success': true};
    }
    return _jsBridge?.handleCall(method, arg) ??
        {'success': false, 'error': 'bridge_unavailable'};
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _themeSurfaceColor(_isDarkTheme);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemUiOverlayStyleForTheme(_isDarkTheme),
      child: Scaffold(
        backgroundColor: themeColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // iOS: explicit strips for status bar + home indicator so they match
            // the web theme (SafeArea is transparent there). Android: same for
            // gesture/nav inset when present.
            if (topInset > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topInset,
                child: ColoredBox(color: themeColor),
              ),
            if (bottomInset > 0)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: bottomInset,
                child: ColoredBox(color: themeColor),
              ),
            SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  InAppWebView(
                    key: _webViewKey,
                    initialUrlRequest:
                        URLRequest(url: WebUri(widget.initialUrl)),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      domStorageEnabled: true,
                      databaseEnabled: true,
                      allowFileAccess: true,
                      allowContentAccess: true,
                      mixedContentMode:
                          MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
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
                      DeepLinkService.instance.onDeepLinkReceived = (url) {
                        controller.loadUrl(
                            urlRequest: URLRequest(url: WebUri(url)));
                      };
                      final initialLink = DeepLinkService.instance.initialLink;
                      if (initialLink != null && initialLink.isNotEmpty) {
                        controller.loadUrl(
                            urlRequest: URLRequest(url: WebUri(initialLink)));
                        DeepLinkService.instance.setInitialLink(null);
                      }
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
                        setState(() =>
                            _errorMessage = 'Нет подключения к интернету');
                      }
                    },
                    onReceivedHttpError: (controller, request, errorResponse) {
                      final code = errorResponse.statusCode;
                      if (code != null && code >= 400 && _isLoading) {
                        setState(
                            () => _errorMessage = 'Ошибка загрузки ($code)');
                      }
                    },
                    shouldOverrideUrlLoading:
                        (controller, navigationAction) async {
                      final uri = navigationAction.request.url;
                      if (uri == null) return NavigationActionPolicy.ALLOW;
                      final scheme = uri.scheme.toLowerCase();

                      if (scheme == 'http' || scheme == 'https') {
                        if (_shouldOpenOAuthInSecureBrowser(uri)) {
                          _openInChromeSafariBrowser(uri);
                          return NavigationActionPolicy.CANCEL;
                        }
                        final host = uri.host;
                        if (host == 'pixapp.kz' ||
                            host.endsWith('.pixapp.kz') ||
                            Env.baseUrl.contains(host)) {
                          return NavigationActionPolicy.ALLOW;
                        }
                        return NavigationActionPolicy.ALLOW;
                      }

                      if (scheme == 'intent') {
                        final intentUrl = uri.toString();
                        _launchIntentOrFallback(intentUrl, null);
                        return NavigationActionPolicy.CANCEL;
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
          ],
        ),
      ),
    );
  }
}
