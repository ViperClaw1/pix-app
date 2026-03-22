import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/logger.dart';
import 'permission_service.dart';

/// Однократная последовательность запросов разрешений при первом запуске.
///
/// Порядок: уведомления → камера → фото/хранилище → геолокация.
/// Сообщения в диалогах — системные; на iOS текст из Info.plist.
class InitialPermissionsService {
  InitialPermissionsService._();

  /// Выполняет последовательность, если ещё не отмечена как завершённая.
  static Future<void> runIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(AppConstants.prefsInitialPermissionsCompleted) == true) {
      return;
    }

    final ps = PermissionService.instance;
    AppLogger.d('InitialPermissions', 'Starting first-launch permission sequence');

    await ps.requestNotifications();
    await ps.requestCamera();
    await ps.requestPhotos();
    await ps.requestStorage();
    await ps.requestLocation();

    await prefs.setBool(AppConstants.prefsInitialPermissionsCompleted, true);
    AppLogger.d('InitialPermissions', 'First-launch permission sequence completed');
  }
}
