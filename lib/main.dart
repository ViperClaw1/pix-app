import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/logger.dart';
import 'services/deep_link_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

  setPreferredOrientations();

  try {
    await Firebase.initializeApp();
    await NotificationService.instance.initialize();
  } catch (e, st) {
    if (kDebugMode) {
      AppLogger.e(
          'main',
          'Firebase/Notifications init failed (add google-services.json / GoogleService-Info.plist)',
          e,
          st);
    }
  }

  try {
    final appLinks = AppLinks();
    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null) {
      DeepLinkService.instance.setInitialLink(initialUri.toString());
    }
  } catch (e, st) {
    if (kDebugMode) {
      AppLogger.e('main', 'getInitialLink', e, st);
    }
  }

  runApp(const PixapApp());
}
