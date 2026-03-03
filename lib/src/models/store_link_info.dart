import 'enums.dart';

/// Информация о ссылке на магазин приложений.
class StoreLinkInfo {
  /// Платформа (ios, android и т.д.)
  final PlatformType platform;

  /// Название магазина (App Store, Google Play и т.д.)
  final String storeName;

  /// URL для открытия страницы приложения в магазине.
  final String url;

  const StoreLinkInfo({
    required this.platform,
    required this.storeName,
    required this.url,
  });

  /// Создание из JSON.
  factory StoreLinkInfo.fromJson(Map<String, dynamic> json) {
    return StoreLinkInfo(
      platform: PlatformType.fromJson(json['platform'] as String),
      storeName: json['storeName'] as String,
      url: json['url'] as String,
    );
  }

  /// Сериализация в JSON.
  Map<String, dynamic> toJson() => {
    'platform': platform.toJson(),
    'storeName': storeName,
    'url': url,
  };

  @override
  String toString() => 'StoreLinkInfo($storeName: $url)';
}
