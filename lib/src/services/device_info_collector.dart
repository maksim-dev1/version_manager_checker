// dart:io используется ТОЛЬКО на нативных платформах (не web).
// На web используем defaultTargetPlatform + device_info_plus webBrowserInfo.
// ignore: avoid_web_libraries_in_flutter
import 'dart:io' show Platform;

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
/// Корректно работает на всех платформах включая Web.
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

    PackageInfo? packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (e) {
      _logger.warning('Не удалось получить PackageInfo: $e');
    }

    final platform = _detectPlatform();
    final version = packageInfo?.version ?? '0.0.0';
    final buildNumber = int.tryParse(packageInfo?.buildNumber ?? '') ?? 0;

    if (kIsWeb) {
      _cachedInfo = await _collectWebInfo(
        platform: platform,
        version: version,
        buildNumber: buildNumber,
      );
    } else {
      _cachedInfo = await _collectNativeInfo(
        platform: platform,
        version: version,
        buildNumber: buildNumber,
      );
    }

    _logger.debug(
      'Устройство: ${_cachedInfo!.deviceModel}, '
      '${_cachedInfo!.platform.name} ${_cachedInfo!.osVersion}',
    );

    return _cachedInfo!;
  }

  // ─── Web ──────────────────────────────────────────────────────────────────

  /// Сбор информации о браузере и устройстве для Web-платформы.
  /// Не использует dart:io.
  Future<DeviceInfo> _collectWebInfo({
    required PlatformType platform,
    required String version,
    required int buildNumber,
  }) async {
    try {
      final webInfo = await _deviceInfoPlugin.webBrowserInfo;
      final userAgent = webInfo.userAgent ?? '';

      final osVersion = _parseOsFromUserAgent(userAgent);
      final deviceModel = _formatBrowserName(webInfo);
      final language = webInfo.language ?? '';

      // Локаль из браузера или PlatformDispatcher
      final locale = PlatformDispatcher.instance.locale;
      final localeStr = language.isNotEmpty
          ? language.replaceAll('-', '_')
          : '${locale.languageCode}_${locale.countryCode ?? ''}';

      // Размер экрана
      int? screenWidth;
      int? screenHeight;
      if (_collectExtendedInfo) {
        final view = PlatformDispatcher.instance.implicitView;
        if (view != null) {
          final size = view.physicalSize / view.devicePixelRatio;
          screenWidth = size.width.toInt();
          screenHeight = size.height.toInt();
        }
      }

      // Тип подключения
      String? connectionType;
      if (_collectExtendedInfo) {
        connectionType = await _getConnectionType();
      }

      const buildType = kDebugMode
          ? 'debug'
          : kProfileMode
          ? 'profile'
          : 'release';

      return DeviceInfo(
        platform: platform,
        version: version,
        buildNumber: buildNumber,
        osVersion: osVersion,
        locale: localeStr,
        deviceModel: deviceModel,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        timezone: _collectExtendedInfo ? DateTime.now().timeZoneName : null,
        connectionType: connectionType,
        buildType: buildType,
        deviceLanguage: locale.languageCode,
      );
    } catch (e) {
      _logger.warning('Частичная ошибка сбора web-инфо: $e');
      return DeviceInfo(
        platform: platform,
        version: version,
        buildNumber: buildNumber,
        buildType: kDebugMode ? 'debug' : 'release',
      );
    }
  }

  /// Парсит название и версию ОС из UserAgent.
  String? _parseOsFromUserAgent(String ua) {
    if (ua.isEmpty) return null;
    // Windows
    final winMatch = RegExp(r'Windows NT ([\d.]+)').firstMatch(ua);
    if (winMatch != null) {
      final ver = winMatch.group(1);
      return switch (ver) {
        '10.0' => 'Windows 10/11',
        '6.3' => 'Windows 8.1',
        '6.2' => 'Windows 8',
        '6.1' => 'Windows 7',
        _ => 'Windows NT $ver',
      };
    }
    // macOS / OS X
    final macMatch = RegExp(r'(?:Mac OS X|macOS) ([\d_]+)').firstMatch(ua);
    if (macMatch != null) {
      final ver = macMatch.group(1)!.replaceAll('_', '.');
      return 'macOS $ver';
    }
    // Android
    final androidMatch = RegExp(r'Android ([\d.]+)').firstMatch(ua);
    if (androidMatch != null) return 'Android ${androidMatch.group(1)}';
    // iOS / iPadOS
    final iosMatch = RegExp(r'(?:iPhone|iPad); CPU.*?OS ([\d_]+)').firstMatch(ua);
    if (iosMatch != null) {
      return 'iOS ${iosMatch.group(1)!.replaceAll('_', '.')}';
    }
    // ChromeOS
    if (ua.contains('CrOS')) return 'ChromeOS';
    // Linux
    if (ua.contains('Linux')) return 'Linux';
    return null;
  }

  /// Форматирует название браузера с версией.
  String _formatBrowserName(WebBrowserInfo info) {
    final ua = info.userAgent ?? '';
    final name = _browserDisplayName(info.browserName);
    final version = _parseBrowserVersion(ua, info.browserName);
    return version != null ? '$name $version' : name;
  }

  String _browserDisplayName(BrowserName browser) => switch (browser) {
    BrowserName.chrome => 'Chrome',
    BrowserName.firefox => 'Firefox',
    BrowserName.safari => 'Safari',
    BrowserName.edge => 'Edge',
    BrowserName.samsungInternet => 'Samsung Internet',
    BrowserName.opera => 'Opera',
    BrowserName.msie => 'Internet Explorer',
    BrowserName.unknown => 'Browser',
  };

  String? _parseBrowserVersion(String ua, BrowserName browser) {
    final pattern = switch (browser) {
      BrowserName.chrome => r'Chrome/(\d+)',
      BrowserName.firefox => r'Firefox/(\d+)',
      BrowserName.safari => r'Version/(\d+)',
      BrowserName.edge => r'Edg/(\d+)',
      BrowserName.opera => r'OPR/(\d+)',
      _ => null,
    };
    if (pattern == null) return null;
    final match = RegExp(pattern).firstMatch(ua);
    return match?.group(1);
  }

  // ─── Native ───────────────────────────────────────────────────────────────

  /// Сбор информации для нативных платформ (iOS, Android, macOS, Windows, Linux).
  Future<DeviceInfo> _collectNativeInfo({
    required PlatformType platform,
    required String version,
    required int buildNumber,
  }) async {
    try {
      final info = await _collectPlatformInfo(platform);

      // Размер экрана
      int? screenWidth;
      int? screenHeight;
      if (_collectExtendedInfo) {
        final view = PlatformDispatcher.instance.implicitView;
        if (view != null) {
          final size = view.physicalSize / view.devicePixelRatio;
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
      final localeStr = '${locale.languageCode}_${locale.countryCode ?? ''}';

      const buildType = kDebugMode
          ? 'debug'
          : kProfileMode
          ? 'profile'
          : 'release';

      // Версия Dart SDK (только нативные)
      String? dartVersion;
      if (_collectExtendedInfo) {
        try {
          dartVersion = Platform.version.split(' ').first;
        } catch (_) {
          dartVersion = null;
        }
      }

      return DeviceInfo(
        platform: platform,
        version: version,
        buildNumber: buildNumber,
        osVersion: info.osVersion,
        locale: localeStr,
        deviceModel: info.deviceModel,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        timezone: _collectExtendedInfo ? DateTime.now().timeZoneName : null,
        frameworkVersion: dartVersion,
        connectionType: connectionType,
        buildType: buildType,
        cpuArchitecture: info.cpuArchitecture,
        totalRamMb: info.totalRamMb,
        deviceLanguage: locale.languageCode,
      );
    } catch (e) {
      _logger.warning('Частичная ошибка сбора native-инфо: $e');
      return DeviceInfo(
        platform: platform,
        version: version,
        buildNumber: buildNumber,
        buildType: kDebugMode ? 'debug' : 'release',
      );
    }
  }

  // ─── Platform detection ───────────────────────────────────────────────────

  /// Определяет текущую платформу.
  /// Использует [kIsWeb] и [defaultTargetPlatform] — без dart:io.
  PlatformType _detectPlatform() {
    if (kIsWeb) return PlatformType.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => PlatformType.ios,
      TargetPlatform.android => PlatformType.android,
      TargetPlatform.macOS => PlatformType.macos,
      TargetPlatform.windows => PlatformType.windows,
      TargetPlatform.linux => PlatformType.linux,
      _ => PlatformType.ios,
    };
  }

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
    );
  }

  Future<_PlatformInfo> _collectMacOsInfo() async {
    final info = await _deviceInfoPlugin.macOsInfo;
    return _PlatformInfo(
      osVersion: '${info.majorVersion}.${info.minorVersion}.${info.patchVersion}',
      deviceModel: info.model,
      cpuArchitecture: _collectExtendedInfo ? info.cpuFrequency.toString() : null,
      totalRamMb: _collectExtendedInfo ? info.memorySize ~/ (1024 * 1024) : null,
    );
  }

  Future<_PlatformInfo> _collectWindowsInfo() async {
    final info = await _deviceInfoPlugin.windowsInfo;
    return _PlatformInfo(
      osVersion: '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}',
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

  // ─── Connectivity ─────────────────────────────────────────────────────────

  Future<String?> _getConnectionType() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result.isEmpty) return 'none';
      return switch (result.first) {
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
}

// ─── Internal ─────────────────────────────────────────────────────────────────

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
