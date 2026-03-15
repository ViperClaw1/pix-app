# Архитектура Pixap Flutter

## Обзор

Приложение — **WebView wrapper**: одна главная сцена с `InAppWebView`, загружающая `BASE_URL` (по умолчанию https://pixapp.kz). Нативная часть предоставляет разрешения, геолокацию, push, выбор файлов и JS bridge для веб-приложения.

## Выбор WebView: flutter_inappwebview

Используется **flutter_inappwebview** (вместо webview_flutter) по причинам:

| Требование | flutter_inappwebview | webview_flutter |
|------------|----------------------|------------------|
| Cookies / localStorage / sessionStorage | Полная поддержка | Ограниченная |
| JavaScript bridge (вызов нативного кода из JS) | `addJavaScriptHandler` + `callHandler` из JS | Только через `runJavaScript` (нет возврата в JS) |
| Загрузка файлов из &lt;input type="file"&gt; | `onShowFileChooser` | Нет встроенной поддержки |
| Настройка (mixed content, cache, user agent) | Широкие опции | Базовые |
| Активная поддержка | Частые обновления | Стабильный, но минимальные фичи |

Итог: для production WebView-обёртки с bridge и загрузкой файлов **flutter_inappwebview** предпочтительнее.

## Структура проекта

```
lib/
  main.dart              # Точка входа, Firebase init
  app.dart                # MaterialApp, маршруты, ориентация

  config/
    env.dart              # ENV, BASE_URL из --dart-define

  core/
    constants.dart        # ID каналов, таймауты, имена bridge
    logger.dart           # Логи (только в debug)

  services/
    permission_service.dart   # Камера, фото, хранилище, геолокация, уведомления
    location_service.dart    # Геолокация (getCurrentPosition, stream)
    notification_service.dart # FCM: токен, foreground/background, передача в WebView
    deep_link_service.dart   # Обработка ссылок pixapp.kz (интерфейс для платформы)

  webview/
    webview_page.dart     # InAppWebView, обработчики ошибок, офлайн, file chooser
    js_bridge.dart        # openCamera, pickFile, getLocation, openExternalLink, события в WebView

  ui/
    splash_screen.dart    # Заставка → переход на /webview
    error_screen.dart     # Ошибка загрузки / сеть + «Повторить»
```

## Окружения (dev / staging / production)

- Задаются через **--dart-define**:
  - `ENV=dev|staging|production`
  - `BASE_URL=https://...` (например https://dev.pixapp.kz)
- В коде: `Env.env`, `Env.baseUrl`, `Env.isDev`, `Env.isStaging`, `Env.isProduction`.
- Используются при старте WebView (`initialUrl`) и при отладке (подпись на splash).

## WebView ↔ Native Bridge

### Вызовы из WebView в нативу

Веб-приложение вызывает методы через `window.PixNative` (инжектируется после загрузки страницы):

- **openCamera(args)** — камера или галерея (`args.source === 'gallery'`), возврат `{ success, path, name }` или `{ success: false, error }`.
- **pickFile(args)** — выбор файла (`args.type === 'image'` только изображения), возврат `{ success, path, name, size }`.
- **getLocation(args)** — текущая геолокация, возврат `{ success, latitude, longitude }` или ошибка.
- **receivePushToken(args)** — веб подтверждает получение токена (no-op на нативной стороне).
- **openExternalLink(args)** — открыть `args.url` в внешнем браузере.

Все методы возвращают Promise (через `callHandler`). При отказе в разрешении возвращается `error: 'permission_denied'`.

### События из нативы в WebView

Нативная часть отправляет события через `CustomEvent('PixNativeEvent', { detail: { type, payload } })`:

- **pushNotificationReceived** — payload от FCM (title, body, data).
- **pushToken** — FCM-токен устройства для отправки на бэкенд.
- **locationUpdated** — при использовании стрима геолокации (latitude, longitude).
- **connectivityChanged** — `{ online: true|false }` при смене сети.

Веб-приложение подписывается: `window.addEventListener('PixNativeEvent', (e) => { e.detail.type, e.detail.payload })`.

## Push-уведомления: рекомендуемая архитектура

Рекомендация: **Firebase Cloud Messaging (FCM)**.

1. **Нативные push** приходят через FCM (Android: канал `pix_app_notifications`, iOS: APNs + FCM).
2. **Токен** после инициализации передаётся в WebView (`pushToken`) — веб отправляет его на свой backend для привязки устройства.
3. **Дублирование in-app**: при получении push в foreground (и при открытии из уведомления) нативная часть шлёт в WebView событие `pushNotificationReceived` с payload — веб может показать свой in-app тост или обновить список уведомлений.

Альтернативы (кратко):

- **WebSocket bridge** — веб держит WebSocket; сервер шлёт события. Подходит для синхронизации in-app, но не заменяет нативные push при закрытом приложении.
- **REST polling** — запросы с устройства к API. Выше нагрузка и задержка, не рекомендуется как основа.
- **Только WebView JS bridge** — без FCM push не придут, когда приложение в фоне/закрыто.

Итог: **FCM для доставки push + JS bridge для передачи токена и payload в WebView** — оптимальная схема.

## Deep Links

- **iOS**: Universal Links. В Xcode: Signing & Capabilities → Associated Domains → `applinks:pixapp.kz`. На домене нужен `apple-app-site-association`.
- **Android**: App Links. В манифесте уже добавлен `intent-filter` с `android:autoVerify="true"` для `https://pixapp.kz` и `https://www.pixapp.kz`. На домене нужен `assetlinks.json`.

Обработка ссылки при холодном/горячем старте должна передавать URL в `DeepLinkService` и затем в WebView (навигация на переданный путь). Конкретная привязка к `getInitialLink` / `uriLinkStream` делается в платформенном коде (или через пакет `app_links`).

## Обработка ошибок

- **Офлайн**: `connectivity_plus` → при `ConnectivityResult.none` в WebView отправляется `connectivityChanged: { online: false }`; при ошибке загрузки (HOST_LOOKUP, CONNECTION) показывается `ErrorScreen` с «Нет подключения к интернету» и кнопкой «Повторить».
- **WebView crash / HTTP error**: при `onReceivedError` (сетевые ошибки) или `onReceivedHttpError` (4xx/5xx) выставляется `_errorMessage` и поверх WebView показывается `ErrorScreen` с повторной загрузкой.
- **Permission denial**: в bridge возвращается `{ success: false, error: 'permission_denied' }`; при необходимости веб может показать сообщение или подсказать открыть настройки (нативная сторона может вызвать `PermissionService.openSettings()`).

## Безопасность (рекомендации)

- **SSL pinning**: не реализован; при необходимости добавить (например, пакет с pinning для WebView или нативно) и закрепить сертификат/публичный ключ для pixapp.kz.
- **Safe Browsing**: на Android можно включить Safe Browsing для WebView (настройки движка); для одного доверенного домена часто не включают.
- **Предотвращение инъекций в WebView**: загружать только доверенный `BASE_URL`; в `shouldOverrideUrlLoading` ограничивать переходы только доменом pixapp.kz (при необходимости — белый список путей).
- **Secure cookies**: сервер должен выставлять cookies с `Secure` и при необходимости `SameSite`; WebView их сохраняет по умолчанию.

## Backend-интеграция

Текущий код **не знает** API веб-приложения. Все запросы к backend идут из веб-части (pixapp.kz). Нативная часть только:

- передаёт FCM-токен в WebView (веб отправляет его на свой API);
- передаёт координаты и результаты выбора файлов в WebView (веб сам решает, куда их отправить).

Если понадобится вызывать backend напрямую из Flutter (например, отдельный сервис синхронизации) — это нужно проектировать отдельно и согласовать с владельцем API.
