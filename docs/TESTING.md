# Тестирование Pixap Flutter

## Локальный запуск

### Android

```bash
flutter run
# или с окружением:
flutter run --dart-define=ENV=dev --dart-define=BASE_URL=https://dev.pixapp.kz
```

Подключите устройство по USB или запустите эмулятор. При первом запуске без `google-services.json` Firebase не инициализируется (в debug логируется ошибка), WebView и bridge работают.

### iOS

```bash
flutter run -d ios
# или
flutter run -d ios --dart-define=ENV=staging --dart-define=BASE_URL=https://staging.pixapp.kz
```

Требуется Xcode и настроенная подпись. Без `GoogleService-Info.plist` push не будут работать, остальное — как на Android.

## Первый запуск: разрешения

При **первой** установке после экрана-заставки последовательно запрашиваются системные диалоги (в таком порядке):

1. Push-уведомления  
2. Камера  
3. Фото / хранилище (зависит от версии ОС)  
4. Геолокация  

Повторно при каждом холодном старте они **не** показываются. Чтобы пройти сценарий заново: удалить приложение и установить снова или сбросить данные приложения (очистит флаг `initial_permissions_completed`).

Тексты на **iOS** берутся из `Info.plist` (`NSUserNotificationsUsageDescription`, `NSCameraUsageDescription`, и т.д.). На **Android** формулировки в диалогах в основном стандартные для ОС.

## Что проверить вручную

1. **WebView**: загрузка BASE_URL, переходы по ссылкам внутри сайта, назад/вперёд при необходимости.
2. **Cookies / localStorage**: авторизация и данные после перезапуска приложения.
3. **JS bridge**: вызов из консоли веб-страницы, например:
   - `window.PixNative.getLocation({}).then(console.log)`
   - `window.PixNative.openCamera({}).then(console.log)`
4. **Файлы**: на странице с `<input type="file">` выбор файла/фото и загрузка.
5. **Офлайн**: отключить сеть — должна появиться ошибка и кнопка «Повторить»; включить сеть и нажать «Повторить».
6. **Разрешения**: отказ в камере/геолокации — в ответе bridge `permission_denied`.

## Push-уведомления

1. Добавить `google-services.json` (Android) и `GoogleService-Info.plist` (iOS) из Firebase Console.
2. В [Firebase Console](https://console.firebase.google.com) → Cloud Messaging отправить тестовое сообщение на устройство (по FCM-токену из логов).
3. Проверить: уведомление в tray; при открытии приложения из push — событие `pushNotificationReceived` в WebView (подписка на `PixNativeEvent`).

## Распространение сборок для тестов

- **Firebase App Distribution**: загрузить AAB/APK (Android) или IPA (iOS) в Firebase App Distribution и пригласить тестировщиков.
- **TestFlight** (iOS): загрузить IPA в App Store Connect и отправить на внутреннее/внешнее тестирование.

Подробности сборки — в [PRODUCTION_BUILD.md](PRODUCTION_BUILD.md).
