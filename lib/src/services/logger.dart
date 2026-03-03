import 'package:flutter/foundation.dart';

import '../config.dart';

/// Утилита логирования для SDK.
class Logger {
  final LogLevel _level;
  final void Function(String message, LogLevel level)? _customLogger;

  const Logger({
    required LogLevel level,
    void Function(String message, LogLevel level)? customLogger,
  }) : _level = level,
       _customLogger = customLogger;

  void _log(String message, LogLevel level) {
    if (level.index > _level.index) return;

    final prefix = switch (level) {
      LogLevel.error => '❌ [VMChecker]',
      LogLevel.warning => '⚠️ [VMChecker]',
      LogLevel.info => 'ℹ️ [VMChecker]',
      LogLevel.debug => '🔍 [VMChecker]',
      LogLevel.none => '',
    };

    if (_customLogger != null) {
      _customLogger('$prefix $message', level);
    } else {
      debugPrint('$prefix $message');
    }
  }

  void error(String message) => _log(message, LogLevel.error);
  void warning(String message) => _log(message, LogLevel.warning);
  void info(String message) => _log(message, LogLevel.info);
  void debug(String message) => _log(message, LogLevel.debug);
}
