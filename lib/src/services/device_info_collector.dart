import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/enums.dart';
import 'logger.dart';

/// Результат сбора информации об устройстве.
class DeviceInfo {
  final PlatformType platform;
  final String version;
  final int buildNumber;
  final String? osVersion;
  final String? locale;
  final String? deviceModel;
  final int? screenWidth;
  final int? screenHeight;
  final String? timezone;
  final String? frameworkVersion;
  final String? connectionType;
  final String buildType;
  final String? cpuArchitecture;
  final int? totalRamMb;
  final String? deviceLanguage;
  final bool? isLowPowerMode;

  const DeviceInfo({
    required this.platform,
    required this.version,
    required this.buildNumber,
    this.osVersion,
    this.locale,
    this.deviceModel,
    this.screenWidth,
    this.screenHeight,
    this.timezone,
    this.frameworkVersion,
    this.connectionType,
    this.buildType = 'release',
    this.cpuArchitecture,
    this.totalRamMb,
    this.deviceLanguage,
    this.isLowPowerMode,
  });
}

/// Сервис сбора информации об устройстве.
///
/// Автоматически определяет платформу, версию ОС, модель устройства,
/// локаль, размер экрана и другие технические метрики.
class DeviceInfoCollector {
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  final Logger _logger;
  final bool _collectExtendedInfo;

  DeviceInfo? _cachedInfo;

  DeviceInfoCollector({required Logger logger, bool collectExtendedInfo = true})
    : _logger = logger,
      _collectExtendedInfo = collectExtendedInfo;

  /// Собирает информацию об устройстве.
  ///
  /// Результат кэшируется — повторные вызовы возвращают кэш.
  /// Для принудительного обновления передайте `forceRefresh: true`.
  Future<DeviceInfo> collect({bool forceRefresh = false}) async {
    if (_cachedInfo != null && !forceRefresh) return _cachedInfo!;

    _logger.debug('Сбор информации об устройстве...');

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final platform = _detectPlatform();

      String? osVersion;
      String? deviceModel;
      String? cpuArchitecture;
      int? totalRamMb;
      bool? isLowPowerMode;

      if (!kIsWeb) {
        final info = await _collectPlatformInfo(platform);
        osVersion = info.osVersion;
        deviceModel = info.deviceModel;
        cpuArchitecture = info.cpuArchitecture;
        totalRamMb = info.totalRamMb;
      } else {
        final webInfo = await _deviceInfoPlugin.webBrowserInfo;
        osVersion = webInfo.platform;
        deviceModel = webInfo.browserName.name;
      }

      // Размер экрана
      int? screenWidth;
      int? screenHeight;
      if (_collectExtendedInfo) {
        final window = PlatformDispatcher.instance.implicitView;
        if (window != null) {
          final size = window.physicalSize / window.devicePixelRatio;
          screenWidth = size.width.toInt();
          screenHeight = size.height.toInt();
        }
      }

      // Тип подключения
      String? connectionType;
      if (_collectExtendedInfo) {
        connectionType = await _getConnectionType();
      }

      // Локаль
      final locale = PlatformDispatcher.instance.locale;
      final localeString = '${locale.languageCode}_${locale.countryCode ?? ''}';

      // Тип сборки
      const buildType = kDebugMode
          ? 'debug'
          : kProfileMode
          ? 'profile'
          : 'release';

      _cachedInfo = DeviceInfo(
        platform: platform,
        version: packageInfo.version,
        buildNumber: int.tryParse(packageInfo.buildNumber) ?? 0,
        osVersion: osVersion,
        locale: localeString,
        deviceModel: deviceModel,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        timezone: _collectExtendedInfo ? DateTime.now().timeZoneName : null,
        frameworkVersion: _collectExtendedInfo ? _getFlutterVersion() : null,
        connectionType: connectionType,
        buildType: buildType,
        cpuArchitecture: cpuArchitecture,
        totalRamMb: totalRamMb,
        deviceLanguage: locale.languageCode,
        isLowPowerMode: isLowPowerMode,
      );

      _logger.debug(
        'Устройство: ${_cachedInfo!.deviceModel}, '
        '${_cachedInfo!.platform.name} ${_cachedInfo!.osVersion}',
      );

      return _cachedInfo!;
    } catch (e) {
      _logger.error('Ошибка сбора информации об устройстве: $e');
      // Возвращаем минимальную информацию
      final packageInfo = await PackageInfo.fromPlatform();
      return DeviceInfo(
        platform: _detectPlatform(),
        version: packageInfo.version,
        buildNumber: int.tryParse(packageInfo.buildNumber) ?? 0,
      );
    }
  }

  /// Определяет текущую платформу.
  PlatformType _detectPlatform() {
    if (kIsWeb) return PlatformType.web;
    if (Platform.isIOS) return PlatformType.ios;
    if (Platform.isAndroid) return PlatformType.android;
    if (Platform.isMacOS) return PlatformType.macos;
    if (Platform.isWindows) return PlatformType.windows;
    if (Platform.isLinux) return PlatformType.linux;
    return PlatformType.ios;
  }

  /// Собирает платформо-специфичную информацию.
  Future<_PlatformInfo> _collectPlatformInfo(PlatformType platform) async {
    return switch (platform) {
      PlatformType.ios => _collectIosInfo(),
      PlatformType.android => _collectAndroidInfo(),
      PlatformType.macos => _collectMacOsInfo(),
      PlatformType.windows => _collectWindowsInfo(),
      PlatformType.linux => _collectLinuxInfo(),
      _ => Future.value(const _PlatformInfo()),
    };
  }

  Future<_PlatformInfo> _collectIosInfo() async {
    final info = await _deviceInfoPlugin.iosInfo;
    return _PlatformInfo(
      osVersion: info.systemVersion,
      deviceModel: info.utsname.machine,
      cpuArchitecture: _collectExtendedInfo ? 'arm64' : null,
    );
  }

  Future<_PlatformInfo> _collectAndroidInfo() async {
    final info = await _deviceInfoPlugin.androidInfo;
    return _PlatformInfo(
      osVersion: info.version.release,
      deviceModel: '${info.brand} ${info.model}',
      cpuArchitecture: _collectExtendedInfo
          ? (info.supportedAbis.isNotEmpty ? info.supportedAbis.first : null)
          : null,
      totalRamMb: null, // Недоступно напрямую через device_info_plus
    );
  }

  Future<_PlatformInfo> _collectMacOsInfo() async {
    final info = await _deviceInfoPlugin.macOsInfo;
    return _PlatformInfo(
      osVersion:
          '${info.majorVersion}.${info.minorVersion}.${info.patchVersion}',
      deviceModel: info.model,
      cpuArchitecture: _collectExtendedInfo
          ? info.cpuFrequency.toString()
          : null,
      totalRamMb: _collectExtendedInfo
          ? info.memorySize ~/ (1024 * 1024)
          : null,
    );
  }

  Future<_PlatformInfo> _collectWindowsInfo() async {
    final info = await _deviceInfoPlugin.windowsInfo;
    return _PlatformInfo(
      osVersion:
          '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}',
      deviceModel: info.productName,
      totalRamMb: _collectExtendedInfo ? info.systemMemoryInMegabytes : null,
    );
  }

  Future<_PlatformInfo> _collectLinuxInfo() async {
    final info = await _deviceInfoPlugin.linuxInfo;
    return _PlatformInfo(
      osVersion: info.versionId,
      deviceModel: info.prettyName,
    );
  }

  /// Получает тип подключения к сети.
  Future<String?> _getConnectionType() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result.isEmpty) return 'none';
      final primary = result.first;
      return switch (primary) {
        ConnectivityResult.wifi => 'wifi',
        ConnectivityResult.mobile => 'cellular',
        ConnectivityResult.ethernet => 'ethernet',
        ConnectivityResult.vpn => 'vpn',
        ConnectivityResult.bluetooth => 'bluetooth',
        ConnectivityResult.none => 'none',
        _ => 'other',
      };
    } catch (_) {
      return null;
    }
  }

  /// Получает версию Flutter.
  String? _getFlutterVersion() {
    // Через dart:io нельзя получить версию Flutter напрямую,
    // но можно вернуть версию Dart SDK
    return Platform.version.split(' ').first;
  }
}

/// Внутренняя структура для передачи платформо-специфичной информации.
class _PlatformInfo {
  final String? osVersion;
  final String? deviceModel;
  final String? cpuArchitecture;
  final int? totalRamMb;

  const _PlatformInfo({
    this.osVersion,
    this.deviceModel,
    this.cpuArchitecture,
    this.totalRamMb,
  });
}
