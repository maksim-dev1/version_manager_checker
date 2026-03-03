import 'enums.dart';

/// Запрос проверки версии мобильного приложения.
///
/// Содержит обязательные поля для идентификации приложения и версии,
/// а также опциональные поля для сбора анонимной технической статистики.
class CheckRequest {
  // === Обязательные поля ===

  /// Уникальный идентификатор приложения (например: com.example.myapp).
  final String namespace;

  /// Текущая семантическая версия приложения (MAJOR.MINOR.PATCH).
  final String version;

  /// Текущий номер сборки приложения.
  final int buildNumber;

  /// Платформа устройства.
  final PlatformType platform;

  // === Идентификация экземпляра ===

  /// Идентификатор экземпляра приложения.
  /// — iOS: identifierForVendor (IDFV)
  /// — Android: генерируемый App Instance ID
  final String? instanceId;

  // === Информация об устройстве ===

  /// Версия операционной системы (например: "17.2.1").
  final String? osVersion;

  /// Локаль пользователя (например: "ru_RU").
  final String? locale;

  /// Модель устройства (например: "iPhone 15 Pro").
  final String? deviceModel;

  // === Расширенная техническая информация ===

  /// Ширина экрана в логических пикселях.
  final int? screenWidth;

  /// Высота экрана в логических пикселях.
  final int? screenHeight;

  /// Часовой пояс устройства (IANA, например: "Europe/Moscow").
  final String? timezone;

  /// Версия фреймворка (Flutter и т.д.).
  final String? frameworkVersion;

  /// Тип соединения (wifi, cellular, ethernet, none).
  final String? connectionType;

  /// Тип сборки (debug, profile, release).
  final String? buildType;

  /// Архитектура CPU (arm64, x86_64 и т.д.).
  final String? cpuArchitecture;

  /// Общий объём оперативной памяти устройства в МБ.
  final int? totalRamMb;

  /// Свободное хранилище устройства в МБ.
  final int? freeStorageMb;

  /// Язык интерфейса устройства (ISO 639-1).
  final String? deviceLanguage;

  /// Включён ли режим энергосбережения.
  final bool? isLowPowerMode;

  /// Версия клиентского SDK.
  final String? sdkVersion;

  const CheckRequest({
    required this.namespace,
    required this.version,
    required this.buildNumber,
    required this.platform,
    this.instanceId,
    this.osVersion,
    this.locale,
    this.deviceModel,
    this.screenWidth,
    this.screenHeight,
    this.timezone,
    this.frameworkVersion,
    this.connectionType,
    this.buildType,
    this.cpuArchitecture,
    this.totalRamMb,
    this.freeStorageMb,
    this.deviceLanguage,
    this.isLowPowerMode,
    this.sdkVersion,
  });

  /// Сериализация в JSON для отправки на сервер.
  Map<String, dynamic> toJson() => {
    'namespace': namespace,
    'version': version,
    'buildNumber': buildNumber,
    'platform': platform.toJson(),
    if (instanceId != null) 'instanceId': instanceId,
    if (osVersion != null) 'osVersion': osVersion,
    if (locale != null) 'locale': locale,
    if (deviceModel != null) 'deviceModel': deviceModel,
    if (screenWidth != null) 'screenWidth': screenWidth,
    if (screenHeight != null) 'screenHeight': screenHeight,
    if (timezone != null) 'timezone': timezone,
    if (frameworkVersion != null) 'frameworkVersion': frameworkVersion,
    if (connectionType != null) 'connectionType': connectionType,
    if (buildType != null) 'buildType': buildType,
    if (cpuArchitecture != null) 'cpuArchitecture': cpuArchitecture,
    if (totalRamMb != null) 'totalRamMb': totalRamMb,
    if (freeStorageMb != null) 'freeStorageMb': freeStorageMb,
    if (deviceLanguage != null) 'deviceLanguage': deviceLanguage,
    if (isLowPowerMode != null) 'isLowPowerMode': isLowPowerMode,
    if (sdkVersion != null) 'sdkVersion': sdkVersion,
  };

  @override
  String toString() =>
      'CheckRequest($namespace v$version+$buildNumber ${platform.name})';
}
