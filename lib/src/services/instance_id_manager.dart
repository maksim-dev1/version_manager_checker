import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logger.dart';

/// Менеджер идентификатора экземпляра приложения.
///
/// Управляет per-app instance ID:
/// — iOS: `identifierForVendor` (IDFV) — сбрасывается при удалении приложения
/// — Android: генерируемый UUID, сохраняемый в SharedPreferences
/// — Другие платформы: генерируемый UUID
///
/// Не требует ATT dialog, consent popup или disclosure в магазинах.
class InstanceIdManager {
  static const _storageKey = 'vm_checker_instance_id';

  final Logger _logger;

  InstanceIdManager({required Logger logger}) : _logger = logger;

  /// Получает или генерирует instance ID.
  Future<String?> getInstanceId() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        return await _getIosInstanceId();
      }

      // Для Android и других платформ — генерируем и сохраняем UUID.
      return await _getOrCreateStoredId();
    } catch (e) {
      _logger.warning('Не удалось получить instance ID: $e');
      return null;
    }
  }

  /// Получает IDFV на iOS.
  Future<String?> _getIosInstanceId() async {
    final info = await DeviceInfoPlugin().iosInfo;
    final idfv = info.identifierForVendor;
    _logger.debug(
      'iOS IDFV: ${idfv != null ? "${idfv.substring(0, 8)}..." : "null"}',
    );
    return idfv;
  }

  /// Получает или создаёт сохранённый instance ID.
  Future<String> _getOrCreateStoredId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_storageKey);

    if (id == null) {
      id = _generateUuid();
      await prefs.setString(_storageKey, id);
      _logger.debug('Создан новый instance ID: ${id.substring(0, 8)}...');
    } else {
      _logger.debug('Загружен instance ID: ${id.substring(0, 8)}...');
    }

    return id;
  }

  /// Генерирует UUID v4 без внешних зависимостей.
  String _generateUuid() {
    final random = DateTime.now().microsecondsSinceEpoch;
    // Простая генерация UUID-like строки
    const chars = '0123456789abcdef';
    final buffer = StringBuffer();

    for (var i = 0; i < 32; i++) {
      if (i == 8 || i == 12 || i == 16 || i == 20) {
        buffer.write('-');
      }
      final index = ((random + i * 7 + i * i * 13) % chars.length).abs();
      buffer.write(chars[index]);
    }

    return buffer.toString();
  }

  /// Сбрасывает сохранённый instance ID.
  /// Полезно для тестирования.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    _logger.debug('Instance ID сброшен');
  }
}
