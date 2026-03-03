import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/check_request.dart';
import '../models/check_response.dart';
import '../models/checker_exception.dart';
import 'logger.dart';

/// HTTP-клиент для взаимодействия с API Version Manager.
class ApiService {
  final String _serverUrl;
  final String _apiKey;
  final Duration _timeout;
  final Map<String, String>? _customHeaders;
  final Logger _logger;

  http.Client? _httpClient;

  ApiService({
    required String serverUrl,
    required String apiKey,
    required Duration timeout,
    Map<String, String>? customHeaders,
    required Logger logger,
  }) : _serverUrl = serverUrl.endsWith('/')
           ? serverUrl.substring(0, serverUrl.length - 1)
           : serverUrl,
       // Убираем пробелы и переносы строки — иначе HTTP-заголовок будет невалиден
       _apiKey = apiKey.trim(),
       _timeout = timeout,
       _customHeaders = customHeaders,
       _logger = logger;

  /// HTTP-клиент. Можно подменить для тестирования.
  http.Client get httpClient => _httpClient ??= http.Client();
  set httpClient(http.Client client) => _httpClient = client;

  /// Выполняет запрос проверки версии.
  ///
  /// Отправляет POST-запрос на `/api/v1/check-version`.
  /// Возвращает [CheckResponse] при успешном ответе (200 OK).
  /// Бросает [ApiException] при ошибках API (400, 401, 404 и т.д.).
  /// Бросает [NetworkException] при проблемах с сетью.
  /// Бросает [TimeoutException] при превышении таймаута.
  /// Бросает [ParseException] при ошибке парсинга ответа.
  Future<CheckResponse> checkVersion(CheckRequest request) async {
    final url = Uri.parse('$_serverUrl/api/v1/check-version');
    final body = jsonEncode(request.toJson());

    _logger.debug('→ POST $url');
    _logger.debug('→ Body: $body');

    final http.Response response;
    try {
      response = await httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $_apiKey',
              if (_customHeaders != null) ..._customHeaders,
            },
            body: body,
          )
          .timeout(_timeout);
    } on http.ClientException catch (e) {
      _logger.error('Ошибка сети: $e');
      throw NetworkException(
        'Не удалось подключиться к серверу: ${e.message}',
        cause: e,
      );
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) {
        _logger.error('Таймаут запроса');
        throw const TimeoutException();
      }
      _logger.error('Ошибка запроса: $e');
      throw NetworkException('Ошибка запроса: $e', cause: e);
    }

    _logger.debug('← ${response.statusCode} ${response.reasonPhrase}');
    _logger.debug('← Body: ${response.body}');

    // Успешный ответ — парсим JSON
    if (response.statusCode == 200) {
      late Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw ParseException(
          'Не удалось разобрать ответ сервера: ${response.body}',
          e,
        );
      }
      try {
        return CheckResponse.fromJson(json);
      } catch (e) {
        throw ParseException('Ошибка парсинга CheckResponse: $e', e);
      }
    }

    // Ошибка — пробуем разобрать как JSON, иначе plain text
    Map<String, dynamic>? errorJson;
    try {
      errorJson = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // Сервер вернул plain text (например, ошибка до нашего route handler)
      throw ApiException(
        errorCode: 'server_error',
        statusCode: response.statusCode,
        message: response.body.isNotEmpty
            ? response.body
            : 'HTTP ${response.statusCode}',
      );
    }
    throw ApiException.fromJson(response.statusCode, errorJson);
  }

  /// Закрывает HTTP-клиент.
  void dispose() {
    _httpClient?.close();
    _httpClient = null;
  }
}
