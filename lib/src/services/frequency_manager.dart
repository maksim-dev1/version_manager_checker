import 'package:shared_preferences/shared_preferences.dart';

import '../models/enums.dart';
import '../models/recommended_version_info.dart';
import 'logger.dart';

/// Менеджер частоты показа рекомендаций обновления.
///
/// Управляет логикой показа диалога обновления на основе
/// server-driven настроек:
/// - [RecommendationFrequency.everyLaunch] — каждый запуск
/// - [RecommendationFrequency.everyNthLaunch] — каждый N-й запуск
/// - [RecommendationFrequency.oncePer] — раз в заданный период
/// - [RecommendationFrequency.once] — один раз
class FrequencyManager {
  static const _prefixKey = 'vm_checker_freq_';
  static const _launchCountKey = '${_prefixKey}launch_count';
  static const _lastShownKey = '${_prefixKey}last_shown';
  static const _shownVersionsKey = '${_prefixKey}shown_versions';
  static const _dismissedVersionsKey = '${_prefixKey}dismissed_versions';

  final Logger _logger;

  FrequencyManager({required Logger logger}) : _logger = logger;

  /// Определяет, нужно ли показывать диалог обновления.
  ///
  /// Учитывает серверные настройки частоты из [recommendedVersion]:
  /// - `everyLaunch` — всегда `true`
  /// - `everyNthLaunch` — `true` каждый N-й запуск
  /// - `oncePer` — `true` если прошло достаточно времени
  /// - `once` — `true` только если ещё не показывали для этой версии
  ///
  /// Для критических обновлений (blocked) всегда возвращает `true`.
  Future<bool> shouldShowPrompt({
    required RecommendedVersionInfo recommendedVersion,
    bool isBlocked = false,
  }) async {
    // Критические обновления показываем всегда.
    if (isBlocked) {
      _logger.debug('Блокировка — показываем всегда');
      return true;
    }

    final frequency = recommendedVersion.recommendationFrequency;

    // Если частота не задана — показываем каждый раз.
    if (frequency == null) {
      _logger.debug('Частота не задана — показываем');
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final targetVersion = recommendedVersion.versionNumber;

    return switch (frequency) {
      RecommendationFrequency.everyLaunch => _handleEveryLaunch(),
      RecommendationFrequency.everyNthLaunch => _handleEveryNthLaunch(
        prefs,
        recommendedVersion.recommendationEveryNthLaunch ?? 3,
      ),
      RecommendationFrequency.oncePer => _handleOncePer(
        prefs,
        recommendedVersion.recommendationPeriodHours ?? 24,
        targetVersion,
      ),
      RecommendationFrequency.once => _handleOnce(prefs, targetVersion),
    };
  }

  /// Фиксирует показ диалога обновления.
  ///
  /// Вызывайте после того, как диалог был показан пользователю.
  Future<void> markPromptShown({required String version}) async {
    final prefs = await SharedPreferences.getInstance();

    // Обновляем время последнего показа
    await prefs.setInt(_lastShownKey, DateTime.now().millisecondsSinceEpoch);

    // Добавляем версию в список показанных
    final shown = prefs.getStringList(_shownVersionsKey) ?? [];
    if (!shown.contains(version)) {
      shown.add(version);
      await prefs.setStringList(_shownVersionsKey, shown);
    }

    _logger.debug('Отмечен показ промпта для v$version');
  }

  /// Фиксирует, что пользователь отклонил обновление.
  Future<void> markPromptDismissed({required String version}) async {
    final prefs = await SharedPreferences.getInstance();

    final dismissed = prefs.getStringList(_dismissedVersionsKey) ?? [];
    if (!dismissed.contains(version)) {
      dismissed.add(version);
      await prefs.setStringList(_dismissedVersionsKey, dismissed);
    }

    _logger.debug('Обновление v$version отклонено пользователем');
  }

  /// Инкрементирует счётчик запусков.
  ///
  /// Вызывайте при каждом запуске приложения.
  Future<int> incrementLaunchCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_launchCountKey) ?? 0) + 1;
    await prefs.setInt(_launchCountKey, count);
    _logger.debug('Счётчик запусков: $count');
    return count;
  }

  /// Сбрасывает все данные о частоте.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefixKey));
    for (final key in keys) {
      await prefs.remove(key);
    }
    _logger.debug('Данные частоты сброшены');
  }

  // === Обработчики частоты ===

  bool _handleEveryLaunch() {
    _logger.debug('everyLaunch → показываем');
    return true;
  }

  Future<bool> _handleEveryNthLaunch(SharedPreferences prefs, int n) async {
    final count = prefs.getInt(_launchCountKey) ?? 1;
    final shouldShow = count % n == 0;
    _logger.debug(
      'everyNthLaunch($n): запуск #$count → '
      '${shouldShow ? "показываем" : "пропускаем"}',
    );
    return shouldShow;
  }

  Future<bool> _handleOncePer(
    SharedPreferences prefs,
    int periodHours,
    String version,
  ) async {
    final lastShown = prefs.getInt(_lastShownKey);

    if (lastShown == null) {
      _logger.debug('oncePer(${periodHours}h): ещё не показывали → показываем');
      return true;
    }

    final lastShownDate = DateTime.fromMillisecondsSinceEpoch(lastShown);
    final elapsed = DateTime.now().difference(lastShownDate);
    final shouldShow = elapsed.inHours >= periodHours;

    _logger.debug(
      'oncePer(${periodHours}h): прошло ${elapsed.inHours}ч → '
      '${shouldShow ? "показываем" : "пропускаем"}',
    );

    return shouldShow;
  }

  Future<bool> _handleOnce(SharedPreferences prefs, String version) async {
    final shown = prefs.getStringList(_shownVersionsKey) ?? [];
    final alreadyShown = shown.contains(version);

    _logger.debug(
      'once(v$version): '
      '${alreadyShown ? "уже показывали → пропускаем" : "не показывали → показываем"}',
    );

    return !alreadyShown;
  }
}
