import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/env.dart';
import 'core/constants.dart';
import 'ui/splash_screen.dart';
import 'webview/webview_page.dart';

class PixApp extends StatelessWidget {
  const PixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PIX',
      debugShowCheckedModeBanner: !Env.isProduction,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/webview': (context) => WebViewPage(
              initialUrl: Env.baseUrl,
              channelId: AppConstants.notificationChannelId,
            ),
      },
    );
  }
}

void setPreferredOrientations() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}
