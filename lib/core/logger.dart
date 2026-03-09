import 'package:flutter/foundation.dart';

/// Простой логгер с учётом окружения.
class AppLogger {
  AppLogger._();

  static void d(String tag, [Object? message, Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[$tag] $message');
      if (error != null) {
        // ignore: avoid_print
        print('  error: $error');
        if (stackTrace != null) {
          // ignore: avoid_print
          print(stackTrace);
        }
      }
    }
  }

  static void w(String tag, [Object? message]) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[$tag] WARN: $message');
    }
  }

  static void e(String tag, [Object? message, Object? error, StackTrace? stackTrace]) {
    // ignore: avoid_print
    print('[$tag] ERROR: $message');
    if (error != null) {
      // ignore: avoid_print
      print('  $error');
      if (stackTrace != null) {
        // ignore: avoid_print
        print(stackTrace);
      }
    }
  }
}
