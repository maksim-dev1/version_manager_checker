import 'package:flutter/foundation.dart';

/// Уровень логирования SDK.
enum LogLevel {
  /// Логирование отключено.
  none,

  /// Только ошибки.
  error,

  /// Предупреждения и ошибки.
  warning,

  /// Информационные сообщения, предупреждения и ошибки.
  info,

  /// Все сообщения включая отладочные.
  debug,
}

/// Конфигурация SDK проверки версий.
class VersionCheckerConfig {
  /// Таймаут HTTP-запроса.
  /// По умолчанию 10 секунд.
  final Duration timeout;

  /// Уровень логирования.
  /// По умолчанию [LogLevel.none] в release, [LogLevel.debug] в debug.
  final LogLevel logLevel;

  /// Автоматическая проверка при инициализации.
  /// По умолчанию `true`.
  final bool checkOnInit;

  /// Автоматический сбор информации об устройстве.
  /// По умолчанию `true`.
  final bool collectDeviceInfo;

  /// Автоматическое управление instance ID.
  /// По умолчанию `true`.
  final bool manageInstanceId;

  /// Собирать расширенную техническую информацию
  /// (экран, RAM, хранилище, CPU архитектура и т.д.).
  /// По умолчанию `true`.
  final bool collectExtendedInfo;

  /// Пользовательские заголовки для HTTP-запросов.
  final Map<String, String>? customHeaders;

  /// Callback для логирования. Если не задан, используется [debugPrint].
  final void Function(String message, LogLevel level)? logger;

  /// Callback при ошибке проверки.
  /// Вызывается если проверка не удалась (сеть, сервер и т.д.).
  /// Полезно для отправки в crash-аналитику.
  final void Function(Object error, StackTrace stackTrace)? onError;

  const VersionCheckerConfig({
    this.timeout = const Duration(seconds: 10),
    this.logLevel = LogLevel.none,
    this.checkOnInit = true,
    this.collectDeviceInfo = true,
    this.manageInstanceId = true,
    this.collectExtendedInfo = true,
    this.customHeaders,
    this.logger,
    this.onError,
  });

  /// Конфигурация по умолчанию для debug-сборки.
  factory VersionCheckerConfig.debug() {
    return const VersionCheckerConfig(
      logLevel: LogLevel.debug,
      timeout: Duration(seconds: 30),
    );
  }

  /// Конфигурация по умолчанию для release-сборки.
  factory VersionCheckerConfig.release() {
    return const VersionCheckerConfig(
      logLevel: LogLevel.none,
      timeout: Duration(seconds: 10),
    );
  }

  /// Автоматическая конфигурация в зависимости от типа сборки.
  factory VersionCheckerConfig.auto() {
    return kDebugMode
        ? VersionCheckerConfig.debug()
        : VersionCheckerConfig.release();
  }
}
