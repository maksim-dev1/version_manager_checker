/// Статус ответа проверки версии.
enum ResponseStatus {
  /// Версия заблокирована — приложение не должно работать.
  blocked,

  /// Доступно обновление.
  updateAvailable,

  /// Версия актуальна.
  active,

  /// Ошибка при проверке.
  error;

  /// Парсинг из JSON строки.
  static ResponseStatus fromJson(String value) {
    return switch (value) {
      'blocked' => ResponseStatus.blocked,
      'update_available' => ResponseStatus.updateAvailable,
      'active' => ResponseStatus.active,
      'error' => ResponseStatus.error,
      _ => ResponseStatus.error,
    };
  }

  /// Сериализация в JSON строку.
  String toJson() {
    return switch (this) {
      ResponseStatus.blocked => 'blocked',
      ResponseStatus.updateAvailable => 'update_available',
      ResponseStatus.active => 'active',
      ResponseStatus.error => 'error',
    };
  }
}

/// Приоритет обновления.
enum UpdatePriority {
  /// Критическое — версия заблокирована, обновление обязательно.
  critical,

  /// Высокий — серьёзные проблемы, настоятельно рекомендуется обновиться.
  high,

  /// Средний — полезные улучшения и исправления.
  medium,

  /// Низкий — незначительные улучшения, обновление опционально.
  low;

  /// Парсинг из JSON строки.
  static UpdatePriority? fromJson(String? value) {
    if (value == null) return null;
    return switch (value) {
      'critical' => UpdatePriority.critical,
      'high' => UpdatePriority.high,
      'medium' => UpdatePriority.medium,
      'low' => UpdatePriority.low,
      _ => null,
    };
  }

  /// Сериализация в JSON строку.
  String toJson() => name;
}

/// Тип платформы.
enum PlatformType {
  ios,
  android,
  web,
  macos,
  windows,
  linux;

  /// Парсинг из JSON строки.
  static PlatformType fromJson(String value) {
    return switch (value) {
      'ios' => PlatformType.ios,
      'android' => PlatformType.android,
      'web' => PlatformType.web,
      'macos' => PlatformType.macos,
      'windows' => PlatformType.windows,
      'linux' => PlatformType.linux,
      _ => PlatformType.ios,
    };
  }

  /// Сериализация в JSON строку.
  String toJson() => name;
}

/// Тип частоты показа рекомендации обновления.
enum RecommendationFrequency {
  /// Каждый запуск приложения.
  everyLaunch,

  /// Каждый N-й запуск.
  everyNthLaunch,

  /// Раз в заданный период.
  oncePer,

  /// Показать один раз и больше не показывать.
  once;

  /// Парсинг из JSON строки.
  static RecommendationFrequency? fromJson(String? value) {
    if (value == null) return null;
    return switch (value) {
      'everyLaunch' => RecommendationFrequency.everyLaunch,
      'everyNthLaunch' => RecommendationFrequency.everyNthLaunch,
      'oncePer' => RecommendationFrequency.oncePer,
      'once' => RecommendationFrequency.once,
      _ => null,
    };
  }

  /// Сериализация в JSON строку.
  String toJson() => name;
}
