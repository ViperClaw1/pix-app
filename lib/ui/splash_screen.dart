import 'package:flutter/material.dart';

import '../config/env.dart';

/// Экран загрузки перед открытием WebView.
/// Проверяет окружение и переходит на WebView.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToWebView());
  }

  void _navigateToWebView() async {
    await Future.delayed(const Duration(milliseconds: 800));
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
