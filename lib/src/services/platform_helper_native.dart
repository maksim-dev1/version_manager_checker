import 'dart:io' show Platform;

/// Нативная реализация — возвращает версию Dart SDK через dart:io.
String? getNativeDartVersion() {
  try {
    return Platform.version.split(' ').first;
  } catch (_) {
    return null;
  }
}
