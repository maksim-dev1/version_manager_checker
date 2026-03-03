import 'dart:async';

import 'config.dart';
import 'models/check_request.dart';
import 'models/check_response.dart';
import 'models/checker_exception.dart';
import 'models/enums.dart';
import 'services/api_service.dart';
import 'services/device_info_collector.dart';
import 'services/frequency_manager.dart';
import 'services/instance_id_manager.dart';
import 'services/logger.dart';

/// Версия SDK.
const String sdkVersion = '1.0.0';

/// Главный класс SDK для проверки версий приложений.
///
/// ## Инициализация
///
/// ```dart
/// await VersionChecker.initialize(
///   serverUrl: 'https://api.example.com',
///   apiKey: 'your-api-key',
///   namespace: 'com.example.myapp',
/// );
/// ```
///
/// ## Проверка версии
///
/// ```dart
/// final response = await VersionChecker.instance.check();
///
/// if (response.isForceUpdateRequired) {
///   // Показать блокирующий экран
/// } else if (response.isUpdateAvailable) {
///   if (await VersionChecker.instance.shouldShowUpdatePrompt(response)) {
///     // Показать диалог обновления
///   }
/// }
/// ```
///
/// ## Виджет-обёртка (рекомендуемый способ)
///
/// ```dart
/// VersionCheckerBuilder(
///   child: MyApp(),
/// );
/// ```
class VersionChecker {
  // === Singleton ===

  static VersionChecker? _instance;

  /// Получение инициализированного экземпляра.
  ///
  /// Бросает [NotInitializedException] если не инициализирован.
  static VersionChecker get instance {
    if (_instance == null) throw const NotInitializedException();
    return _instance!;
  }

  /// Инициализирован ли SDK.
  static bool get isInitialized => _instance != null;

  // === Зависимости ===

  final String _serverUrl;
  final String _namespace;
  final VersionCheckerConfig _config;
  final Logger _logger;
  final ApiService _apiService;
  final DeviceInfoCollector _deviceInfoCollector;
  final InstanceIdManager _instanceIdManager;
  final FrequencyManager _frequencyManager;

  /// Последний результат проверки.
  CheckResponse? _lastResponse;

  /// Последний результат проверки версии.
  /// `null` если проверка ещё не выполнялась.
  CheckResponse? get lastResponse => _lastResponse;

  VersionChecker._({
    required String serverUrl,
    required String namespace,
    required VersionCheckerConfig config,
    required Logger logger,
    required ApiService apiService,
    required DeviceInfoCollector deviceInfoCollector,
    required InstanceIdManager instanceIdManager,
    required FrequencyManager frequencyManager,
  }) : _serverUrl = serverUrl,
       _namespace = namespace,
       _config = config,
       _logger = logger,
       _apiService = apiService,
       _deviceInfoCollector = deviceInfoCollector,
       _instanceIdManager = instanceIdManager,
       _frequencyManager = frequencyManager;

  /// Инициализирует SDK.
  ///
  /// [serverUrl] — URL сервера Version Manager (например: "https://api.example.com").
  /// [apiKey] — API-ключ приложения из панели управления.
  /// [namespace] — Уникальный идентификатор приложения (например: "com.example.myapp").
  /// [config] — Конфигурация SDK. По умолчанию автоматическая.
  ///
  /// Возвращает результат первой проверки, если [VersionCheckerConfig.checkOnInit] == true.
  ///
  /// ```dart
  /// final response = await VersionChecker.initialize(
  ///   serverUrl: 'https://api.example.com',
  ///   apiKey: 'vm_k_abc123',
  ///   namespace: 'com.example.myapp',
  /// );
  ///
  /// if (response?.isForceUpdateRequired == true) {
  ///   // Версия заблокирована
  /// }
  /// ```
  static Future<CheckResponse?> initialize({
    required String serverUrl,
    required String apiKey,
    required String namespace,
    VersionCheckerConfig? config,
  }) async {
    final cfg = config ?? VersionCheckerConfig.auto();

    final logger = Logger(level: cfg.logLevel, customLogger: cfg.logger);

    logger.info('Инициализация VersionChecker v$sdkVersion');
    logger.info('Сервер: $serverUrl');
    logger.info('Namespace: $namespace');

    final apiService = ApiService(
      serverUrl: serverUrl,
      apiKey: apiKey,
      timeout: cfg.timeout,
      customHeaders: cfg.customHeaders,
      logger: logger,
    );

    final deviceInfoCollector = DeviceInfoCollector(
      logger: logger,
      collectExtendedInfo: cfg.collectExtendedInfo,
    );

    final instanceIdManager = InstanceIdManager(logger: logger);
    final frequencyManager = FrequencyManager(logger: logger);

    _instance = VersionChecker._(
      serverUrl: serverUrl,
      namespace: namespace,
      config: cfg,
      logger: logger,
      apiService: apiService,
      deviceInfoCollector: deviceInfoCollector,
      instanceIdManager: instanceIdManager,
      frequencyManager: frequencyManager,
    );

    // Инкрементируем счётчик запусков
    await frequencyManager.incrementLaunchCount();

    // Автоматическая проверка при инициализации
    if (cfg.checkOnInit) {
      try {
        return await _instance!.check();
      } catch (e, stackTrace) {
        logger.error('Ошибка автоматической проверки: $e');
        cfg.onError?.call(e, stackTrace);
        return null;
      }
    }

    return null;
  }

  /// Выполняет проверку версии приложения.
  ///
  /// Собирает информацию об устройстве, формирует запрос
  /// и отправляет его на сервер.
  ///
  /// Возвращает [CheckResponse] с результатом проверки.
  ///
  /// Может бросить:
  /// - [NetworkException] — проблемы с сетью
  /// - [ApiException] — ошибка API
  /// - [TimeoutException] — таймаут запроса
  /// - [ParseException] — ошибка парсинга ответа
  Future<CheckResponse> check() async {
    _logger.info('Начинаю проверку версии...');

    // Собираем информацию об устройстве
    DeviceInfo? deviceInfo;
    if (_config.collectDeviceInfo) {
      deviceInfo = await _deviceInfoCollector.collect();
    }

    // Получаем instance ID
    String? instanceId;
    if (_config.manageInstanceId) {
      instanceId = await _instanceIdManager.getInstanceId();
    }

    // Формируем запрос
    final request = CheckRequest(
      namespace: _namespace,
      version: deviceInfo?.version ?? '0.0.0',
      buildNumber: deviceInfo?.buildNumber ?? 0,
      platform: deviceInfo?.platform ?? PlatformType.ios,
      instanceId: instanceId,
      osVersion: deviceInfo?.osVersion,
      locale: deviceInfo?.locale,
      deviceModel: deviceInfo?.deviceModel,
      screenWidth: deviceInfo?.screenWidth,
      screenHeight: deviceInfo?.screenHeight,
      timezone: deviceInfo?.timezone,
      frameworkVersion: deviceInfo?.frameworkVersion,
      connectionType: deviceInfo?.connectionType,
      buildType: deviceInfo?.buildType,
      cpuArchitecture: deviceInfo?.cpuArchitecture,
      totalRamMb: deviceInfo?.totalRamMb,
      deviceLanguage: deviceInfo?.deviceLanguage,
      isLowPowerMode: deviceInfo?.isLowPowerMode,
      sdkVersion: sdkVersion,
    );

    _logger.info('Запрос: $request');

    // Отправляем запрос
    final response = await _apiService.checkVersion(request);

    _logger.info('Ответ: ${response.status.name} — ${response.message}');

    _lastResponse = response;
    return response;
  }

  /// Определяет, нужно ли показывать диалог обновления.
  ///
  /// Учитывает серверные настройки частоты показа.
  /// Для заблокированных версий всегда возвращает `true`.
  ///
  /// ```dart
  /// final response = await VersionChecker.instance.check();
  /// if (response.isUpdateAvailable) {
  ///   if (await VersionChecker.instance.shouldShowUpdatePrompt(response)) {
  ///     showUpdateDialog(context, response);
  ///   }
  /// }
  /// ```
  Future<bool> shouldShowUpdatePrompt(CheckResponse response) async {
    if (response.isForceUpdateRequired) return true;
    if (!response.isUpdateAvailable) return false;
    if (response.recommendedVersion == null) return false;

    return _frequencyManager.shouldShowPrompt(
      recommendedVersion: response.recommendedVersion!,
      isBlocked: response.isBlocked,
    );
  }

  /// Фиксирует показ диалога обновления.
  ///
  /// Вызывайте после того, как диалог был показан пользователю.
  /// Это необходимо для корректной работы частотных настроек.
  Future<void> markPromptShown(String version) async {
    await _frequencyManager.markPromptShown(version: version);
  }

  /// Фиксирует, что пользователь отклонил обновление.
  Future<void> markPromptDismissed(String version) async {
    await _frequencyManager.markPromptDismissed(version: version);
  }

  /// URL сервера.
  String get serverUrl => _serverUrl;

  /// Namespace приложения.
  String get namespace => _namespace;

  /// Текущая конфигурация.
  VersionCheckerConfig get config => _config;

  /// Менеджер частоты показа (для продвинутого использования).
  FrequencyManager get frequencyManager => _frequencyManager;

  /// Освобождает ресурсы SDK.
  void dispose() {
    _apiService.dispose();
    _instance = null;
    _logger.info('VersionChecker освобождён');
  }
}
