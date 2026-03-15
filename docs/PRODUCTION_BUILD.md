# Production Build

## Подготовка

1. **Firebase**
   - Создать проект в [Firebase Console](https://console.firebase.google.com).
   - Добавить приложения Android (package `com.pixap.pixap`) и iOS (bundle id `com.pixap.pixap`).
   - Скачать и положить:
     - `google-services.json` → `android/app/`
     - `GoogleService-Info.plist` → `ios/Runner/`
   - Для iOS: в Xcode включить Push Notifications и при необходимости Background Modes → Remote notifications.
   - Для Android: канал уведомлений задаётся в манифесте (`pix_app_notifications`).

2. **Подпись**
   - **Android**: создать keystore и прописать `signingConfigs` в `android/app/build.gradle.kts` (release).
   - **iOS**: выбрать Team и профиль в Xcode, настроить сертификаты и provisioning для App Store.

3. **Deep Links**
   - **iOS**: Associated Domains → `applinks:pixapp.kz`; на сервере — `apple-app-site-association`.
   - **Android**: уже настроен в манифесте; на сервере — `assetlinks.json` для `https://pixapp.kz`.

## Сборка

### Android

```bash
# AAB (рекомендуется для Google Play)
flutter build appbundle --dart-define=ENV=production --dart-define=BASE_URL=https://pixapp.kz

# APK (для сторонней установки / тестов)
flutter build apk --dart-define=ENV=production --dart-define=BASE_URL=https://pixapp.kz
```

Артефакты:
- AAB: `build/app/outputs/bundle/release/app-release.aab`
- APK: `build/app/outputs/flutter-apk/app-release.apk`

### iOS

```bash
flutter build ipa --dart-define=ENV=production --dart-define=BASE_URL=https://pixapp.kz
```

IPA создаётся в `build/ios/ipa/`. Дальше загрузка в App Store Connect через Xcode (Organizer) или Transporter.

## Codemagic (iOS)

При сборке iOS в Codemagic с **Automatic** code signing обязательно задайте переменную окружения:

- **`DEVELOPMENT_TEAM`** — ваш Apple Developer Team ID (10 символов).

Team ID можно посмотреть: [developer.apple.com/account](https://developer.apple.com/account) → Membership → Team ID.

Без этой переменной Xcode на билдере выдаст ошибку «No Accounts» / «No profiles for 'com.pixap.pixap'».

## Переменные окружения

Для production всегда передавайте:

- `ENV=production`
- `BASE_URL=https://pixapp.kz` (или ваш production-URL)

Иначе в приложении будет использоваться значение по умолчанию из `lib/config/env.dart` (production и https://pixapp.kz).

## Рекомендации по безопасности

- Не хранить секреты в коде; для API ключей использовать переменные окружения или защищённое хранилище.
- Рассмотреть **SSL pinning** для домена pixapp.kz при высоких требованиях к безопасности.
- Регулярно обновлять зависимости (`flutter pub upgrade`) и проверять уязвимости.
