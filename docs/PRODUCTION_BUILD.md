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

4. **Google Play: политика конфиденциальности**
   - Приложение использует разрешения (например, `CAMERA`), для которых Google Play требует **ссылку на политику конфиденциальности**.
   - В [Google Play Console](https://play.google.com/console) → ваше приложение → **Политика** → **Политика конфиденциальности приложения** укажите URL страницы с текстом политики (например, `https://pixapp.kz/privacy` или отдельная страница на вашем сайте). Без этого загрузка релиза будет заблокирована.

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

В репозитории есть **`codemagic.yaml`**: сборка iOS идёт по нему, шаг **`xcode-project use-profiles`** выполняется до `flutter build ipa`, подпись настраивается автоматически.

Что проверить в Codemagic:

1. **Интеграция App Store Connect**  
   Team/Personal → **Integrations** → **Developer Portal** — добавлен API‑ключ (Issuer ID, Key ID, файл .p8). Имя интеграции в `codemagic.yaml` в `integrations.app_store_connect` должно совпадать с именем ключа в Codemagic (по умолчанию в конфиге — `codemagic`).

2. **Тип профиля для IPA**  
   В настройках подписи iOS выберите **App Store** (не Development). Для `flutter build ipa` и загрузки в TestFlight/App Store нужен именно App Store профиль.

3. **Bundle ID**  
   В настройках подписи и в `codemagic.yaml` должен быть **`com.pixap.pixap`**.

4. **После добавления/изменения codemagic.yaml**  
   В приложении Codemagic нажмите **Check for configuration file** по нужной ветке, чтобы подхватить `codemagic.yaml`. Дальше запускайте сборку из этого конфига (по триггеру или вручную).

Если сборка по‑прежнему идёт через **Workflow Editor** (без yaml), задайте переменную окружения **`DEVELOPMENT_TEAM`** — ваш Apple Developer Team ID (10 символов). Team ID: [developer.apple.com/account](https://developer.apple.com/account) → Membership → Team ID.

## Codemagic (Android)

Чтобы AAB подписывался в **release** (а не debug), Codemagic должен передать keystore в сборку. В `codemagic.yaml` для этого добавлен workflow **android-workflow** с `android_signing: [pixap-release-keystore]`.

**Что сделать в Codemagic:**

1. **Code signing identities** → вкладка **Android keystores** → **Add keystore** (или загрузить существующий).
2. Укажите **Reference name**: **`pixap-release-keystore`** (как в `codemagic.yaml`).
3. Загрузите файл **.jks** или **.keystore**, введите пароль keystore, key alias и key password.
4. Сохраните. При сборке по workflow **Android Build** Codemagic подставит `CM_KEYSTORE_PATH`, `CM_KEYSTORE_PASSWORD`, `CM_KEY_ALIAS`, `CM_KEY_PASSWORD` — и `build.gradle.kts` подпишет AAB в release.

Если Android собирается через **Workflow Editor** (без yaml), в настройках этого workflow включите **Android code signing** и выберите загруженный keystore (или укажите тот же reference name в конфиге редактора).

Без настроенной подписи сборка использует **debug** keystore, и Google Play отклонит AAB с сообщением «signed in debug mode».

## Переменные окружения

Для production всегда передавайте:

- `ENV=production`
- `BASE_URL=https://pixapp.kz` (или ваш production-URL)

Иначе в приложении будет использоваться значение по умолчанию из `lib/config/env.dart` (production и https://pixapp.kz).

## Рекомендации по безопасности

- Не хранить секреты в коде; для API ключей использовать переменные окружения или защищённое хранилище.
- Рассмотреть **SSL pinning** для домена pixapp.kz при высоких требованиях к безопасности.
- Регулярно обновлять зависимости (`flutter pub upgrade`) и проверять уязвимости.
