/// Flutter SDK для проверки версий приложений через Version Manager.
///
/// ## Быстрый старт
///
/// ```dart
/// // 1. Инициализация
/// await VersionChecker.initialize(
///   serverUrl: 'https://api.example.com',
///   apiKey: 'your-api-key',
///   namespace: 'com.example.myapp',
/// );
///
/// // 2. Использование виджета (рекомендуется)
/// VersionCheckerBuilder(
///   child: MyApp(),
///   onBlocked: (context, response) => BlockedScreen(response: response),
///   onUpdateAvailable: (context, response) {
///     showUpdateBottomSheet(context: context, response: response);
///   },
/// );
///
/// // 3. Или ручная проверка
/// final response = await VersionChecker.instance.check();
/// ```
library;

// Models
export 'src/models/enums.dart';
export 'src/models/store_link_info.dart';
export 'src/models/recommended_version_info.dart';
export 'src/models/check_request.dart';
export 'src/models/check_response.dart';
export 'src/models/checker_exception.dart';

// Config
export 'src/config.dart';

// Core
export 'src/checker.dart';

// UI
export 'src/ui/blocked_screen.dart';
export 'src/ui/update_bottom_sheet.dart';
export 'src/ui/checker_builder.dart';
