# Version Manager Checker

Flutter SDK для проверки версий приложений через **Version Manager**.

## Возможности

- ✅ Автоматическая проверка версии при запуске
- ✅ Блокировка устаревших версий (force update)
- ✅ Мягкие рекомендации обновления с настраиваемой частотой
- ✅ Автоматический сбор информации об устройстве
- ✅ Per-app Instance ID (IDFV на iOS, UUID на Android)
- ✅ Готовые UI-компоненты (экран блокировки, bottom sheet)
- ✅ Полная кастомизация UI через builder
- ✅ Управление частотой показа рекомендаций (server-driven)
- ✅ Graceful degradation при ошибках сети

## Установка

```yaml
dependencies:
  version_manager_checker:
    path: ../version_manager_checker
```

## Быстрый старт

### 1. Инициализация

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация SDK
  await VersionChecker.initialize(
    serverUrl: 'https://api.example.com',
    apiKey: 'vm_k_your_api_key',
    namespace: 'com.example.myapp',
  );

  runApp(const MyApp());
}
```

### 2. Виджет-обёртка (рекомендуемый способ)

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: VersionCheckerBuilder(
        child: const HomeScreen(),
      ),
    );
  }
}
```

### 3. Ручная проверка

```dart
final response = await VersionChecker.instance.check();

if (response.isForceUpdateRequired) {
  // Версия заблокирована — показать BlockedScreen
} else if (response.isUpdateAvailable) {
  if (await VersionChecker.instance.shouldShowUpdatePrompt(response)) {
    showUpdateBottomSheet(context: context, response: response);
  }
}
```

## Конфигурация

```dart
await VersionChecker.initialize(
  serverUrl: 'https://api.example.com',
  apiKey: 'vm_k_your_api_key',
  namespace: 'com.example.myapp',
  config: VersionCheckerConfig(
    timeout: Duration(seconds: 15),
    logLevel: LogLevel.debug,
    checkOnInit: true,
    collectDeviceInfo: true,
    collectExtendedInfo: true,
    onError: (error, stackTrace) {
      // Отправить в Sentry / Crashlytics
    },
  ),
);
```

## Кастомизация UI

### Кастомный экран блокировки

```dart
VersionCheckerBuilder(
  child: const HomeScreen(),
  blockedBuilder: (context, response) => MyCustomBlockedScreen(
    message: response.message,
    reason: response.blockReason,
  ),
);
```

### Кастомный диалог обновления

```dart
VersionCheckerBuilder(
  child: const HomeScreen(),
  onUpdateAvailable: (context, response) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Обновление v${response.recommendedVersion?.versionNumber}'),
        content: Text(response.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Позже'),
          ),
          FilledButton(
            onPressed: () { /* открыть магазин */ },
            child: const Text('Обновить'),
          ),
        ],
      ),
    );
  },
);
```

### Полный контроль через builder

```dart
VersionCheckerBuilder(
  child: const HomeScreen(),
  builder: (context, state, child) {
    return switch (state) {
      VersionCheckLoading() => const SplashScreen(),
      VersionCheckCompleted(response: final r) when r.isForceUpdateRequired =>
        BlockedScreen(response: r),
      VersionCheckCompleted() => child,
      VersionCheckError() => child,
    };
  },
);
```

## Частота показа рекомендаций

Частота показа управляется сервером через поле `recommendationFrequency`:

| Тип | Описание |
|-----|----------|
| `everyLaunch` | Каждый запуск приложения |
| `everyNthLaunch` | Каждый N-й запуск |
| `oncePer` | Раз в заданный период (часы) |
| `once` | Один раз и больше не показывать |

SDK автоматически учитывает эти настройки при вызове
`shouldShowUpdatePrompt()` и в `VersionCheckerBuilder`.

## Собираемые данные

SDK собирает **только технические метрики устройства** (non-PII):

| Поле | Описание |
|------|----------|
| `platform` | Платформа (ios, android, web...) |
| `version` | Версия приложения |
| `buildNumber` | Номер сборки |
| `instanceId` | Per-app ID (IDFV / UUID) |
| `osVersion` | Версия ОС |
| `deviceModel` | Модель устройства |
| `locale` | Локаль |
| `screenWidth/Height` | Размер экрана |
| `timezone` | Часовой пояс |
| `connectionType` | Тип подключения |
| `buildType` | Тип сборки (debug/release) |

> **Не требует** ATT dialog, consent popup или disclosure в магазинах.

## Архитектура

```
version_manager_checker/
├── lib/
│   ├── version_manager_checker.dart   # Barrel export
│   └── src/
│       ├── checker.dart               # VersionChecker (главный класс)
│       ├── config.dart                # VersionCheckerConfig
│       ├── models/
│       │   ├── enums.dart             # ResponseStatus, UpdatePriority и др.
│       │   ├── check_request.dart     # CheckRequest
│       │   ├── check_response.dart    # CheckResponse
│       │   ├── recommended_version_info.dart
│       │   ├── store_link_info.dart
│       │   └── checker_exception.dart # Типизированные исключения
│       ├── services/
│       │   ├── api_service.dart       # HTTP-клиент
│       │   ├── device_info_collector.dart
│       │   ├── instance_id_manager.dart
│       │   ├── frequency_manager.dart
│       │   └── logger.dart
│       └── ui/
│           ├── blocked_screen.dart    # Экран блокировки
│           ├── update_bottom_sheet.dart # Bottom sheet обновления
│           └── checker_builder.dart   # VersionCheckerBuilder виджет
└── pubspec.yaml
```
