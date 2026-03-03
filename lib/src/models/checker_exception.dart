/// Базовое исключение SDK.
sealed class VersionCheckerException implements Exception {
  final String message;
  final Object? cause;

  const VersionCheckerException(this.message, [this.cause]);

  @override
  String toString() => '$runtimeType: $message';
}

/// SDK не инициализирован.
/// Вызовите [VersionChecker.initialize] перед использованием.
class NotInitializedException extends VersionCheckerException {
  const NotInitializedException()
    : super(
        'VersionChecker не инициализирован. '
        'Вызовите VersionChecker.initialize() перед использованием.',
      );
}

/// Ошибка сети при запросе к серверу.
class NetworkException extends VersionCheckerException {
  final int? statusCode;

  const NetworkException(String message, {this.statusCode, Object? cause})
    : super(message, cause);
}

/// Ошибка API — сервер вернул ошибку.
class ApiException extends VersionCheckerException {
  /// Код ошибки от сервера (например: "invalid_api_key").
  final String errorCode;

  /// HTTP статус код.
  final int statusCode;

  /// Дополнительные детали ошибки.
  final String? details;

  /// Время ответа сервера.
  final DateTime? serverTimestamp;

  const ApiException({
    required this.errorCode,
    required this.statusCode,
    required String message,
    this.details,
    this.serverTimestamp,
  }) : super(message);

  /// Создание из JSON ответа сервера.
  factory ApiException.fromJson(int statusCode, Map<String, dynamic> json) {
    return ApiException(
      errorCode: json['errorCode'] as String? ?? 'unknown',
      statusCode: statusCode,
      message: json['message'] as String? ?? 'Неизвестная ошибка',
      details: json['details'] as String?,
      serverTimestamp: json['serverTimestamp'] != null
          ? DateTime.tryParse(json['serverTimestamp'] as String)
          : null,
    );
  }

  @override
  String toString() => 'ApiException($statusCode $errorCode): $message';
}

/// Ошибка парсинга ответа сервера.
class ParseException extends VersionCheckerException {
  const ParseException(super.message, [super.cause]);
}

/// Таймаут запроса.
class TimeoutException extends VersionCheckerException {
  const TimeoutException([super.message = 'Превышено время ожидания запроса']);
}
