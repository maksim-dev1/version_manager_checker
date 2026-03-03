import 'enums.dart';
import 'store_link_info.dart';

/// Информация о рекомендуемой версии для обновления.
class RecommendedVersionInfo {
  /// Семантическая версия (MAJOR.MINOR.PATCH).
  final String versionNumber;

  /// Номер сборки.
  final int buildNumber;

  /// Описание изменений (changelog).
  final String changelog;

  /// Ссылки на магазины для текущей платформы.
  final List<StoreLinkInfo> storeLinks;

  /// Тип частоты показа рекомендации обновления.
  final RecommendationFrequency? recommendationFrequency;

  /// Интервал для типа [RecommendationFrequency.everyNthLaunch] (от 2 до 50).
  final int? recommendationEveryNthLaunch;

  /// Период в часах для типа [RecommendationFrequency.oncePer].
  final int? recommendationPeriodHours;

  const RecommendedVersionInfo({
    required this.versionNumber,
    required this.buildNumber,
    required this.changelog,
    required this.storeLinks,
    this.recommendationFrequency,
    this.recommendationEveryNthLaunch,
    this.recommendationPeriodHours,
  });

  /// Создание из JSON.
  factory RecommendedVersionInfo.fromJson(Map<String, dynamic> json) {
    return RecommendedVersionInfo(
      versionNumber: json['versionNumber'] as String,
      buildNumber: json['buildNumber'] as int,
      changelog: json['changelog'] as String,
      storeLinks: (json['storeLinks'] as List<dynamic>)
          .map((e) => StoreLinkInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommendationFrequency: RecommendationFrequency.fromJson(
        json['recommendationFrequency'] as String?,
      ),
      recommendationEveryNthLaunch:
          json['recommendationEveryNthLaunch'] as int?,
      recommendationPeriodHours: json['recommendationPeriodHours'] as int?,
    );
  }

  /// Сериализация в JSON.
  Map<String, dynamic> toJson() => {
    'versionNumber': versionNumber,
    'buildNumber': buildNumber,
    'changelog': changelog,
    'storeLinks': storeLinks.map((e) => e.toJson()).toList(),
    if (recommendationFrequency != null)
      'recommendationFrequency': recommendationFrequency!.toJson(),
    if (recommendationEveryNthLaunch != null)
      'recommendationEveryNthLaunch': recommendationEveryNthLaunch,
    if (recommendationPeriodHours != null)
      'recommendationPeriodHours': recommendationPeriodHours,
  };

  @override
  String toString() => 'RecommendedVersionInfo(v$versionNumber+$buildNumber)';
}
