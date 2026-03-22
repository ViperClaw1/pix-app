import 'package:flutter/material.dart';

import '../config/env.dart';
import '../services/initial_permissions_service.dart';
import '../services/notification_service.dart';

/// Экран загрузки перед открытием WebView.
/// После первого кадра сразу запускает цепочку разрешений (первый запуск), затем WebView.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterSplashShown());
  }

  /// Сразу после отрисовки splash: разрешения (если первый запуск) → FCM → WebView.
  Future<void> _afterSplashShown() async {
    if (!mounted) return;
    await InitialPermissionsService.runIfNeeded();
    if (!mounted) return;
    await NotificationService.instance.refreshFcmToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/webview');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/app_icon.png',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
            if (Env.isDev || Env.isStaging) ...[
              const SizedBox(height: 16),
              Text(
                Env.env,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
