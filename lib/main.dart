import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/logger.dart';
import 'services/notification_service.dart';

void main() async {
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

  WidgetsFlutterBinding.ensureInitialized();

  setPreferredOrientations();

  try {
    await Firebase.initializeApp();
    await NotificationService.instance.initialize();
  } catch (e, st) {
    assert(() {
      AppLogger.e(
          'main',
          'Firebase/Notifications init failed (add google-services.json / GoogleService-Info.plist)',
          e,
          st);
      return true;
    }());
  }

  runApp(const PixApp());
}
