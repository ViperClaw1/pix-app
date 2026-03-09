# PIX — Mobile Wrapper для pixapp.kz

Production-ready Flutter приложение, оборачивающее веб-приложение https://pixapp.kz/ в нативную оболочку с доступом к камере, хранилищу, геолокации и push-уведомлениям.

## Структура

`lib/`: `main.dart`, `app.dart`, `config/`, `core/`, `services/`, `webview/`, `ui/`.

## Перед запуском

- **Android**: для push — `google-services.json` в `android/app/` (Firebase Console).
- **iOS**: для push — `GoogleService-Info.plist` в `ios/Runner/`, Push Notifications и Background Modes → Remote notifications в Xcode.

Без конфигов Firebase приложение запускается, push не работают.

## Окружения

```bash
# Development
flutter run --dart-define=ENV=dev --dart-define=BASE_URL=https://dev.pixapp.kz

# Staging
flutter run --dart-define=ENV=staging --dart-define=BASE_URL=https://staging.pixapp.kz

# Production (по умолчанию)
flutter run --dart-define=ENV=production --dart-define=BASE_URL=https://pixapp.kz
```

## Архитектура

См. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Сборка

См. [docs/PRODUCTION_BUILD.md](docs/PRODUCTION_BUILD.md).

## Тестирование

См. [docs/TESTING.md](docs/TESTING.md).
