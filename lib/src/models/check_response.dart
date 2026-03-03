import 'enums.dart';
import 'recommended_version_info.dart';

/// Ответ на проверку версии мобильного приложения.
///
/// Содержит информацию о статусе текущей версии, необходимости обновления,
/// приоритете и ссылках на магазины.
class CheckResponse {
  /// Статус текущей версии.
  final ResponseStatus status;

  /// Заблокирована ли текущая версия.
  /// Если `true` — клиент должен показать полноэкранный блокирующий экран.
  final bool isBlocked;

  /// Причина блокировки (только если [isBlocked] == true).
  final String? blockReason;

  /// Приоритет обновления.
  /// `null` если версия актуальна ([status] == [ResponseStatus.active]).
  final UpdatePriority? updatePriority;

  /// Информация о рекомендуемой версии для обновления.
  /// `null` если нет рекомендованной версии или версия актуальна.
  final RecommendedVersionInfo? recommendedVersion;

  /// Сообщение для отображения пользователю.
  final String message;

  /// Текущий номер версии приложения (echo для подтверждения).
  final String currentVersion;

  /// Текущий номер сборки (echo для подтверждения).
  final int currentBuildNumber;

  /// Время обработки запроса на сервере.
  final DateTime serverTimestamp;

  const CheckResponse({
    required this.status,
    required this.isBlocked,
    this.blockReason,
    this.updatePriority,
    this.recommendedVersion,
    required this.message,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.serverTimestamp,
  });

  /// Создание из JSON ответа сервера.
  factory CheckResponse.fromJson(Map<String, dynamic> json) {
    return CheckResponse(
      status: ResponseStatus.fromJson(json['status'] as String),
      isBlocked: json['isBlocked'] as bool,
      blockReason: json['blockReason'] as String?,
      updatePriority: UpdatePriority.fromJson(
        json['updatePriority'] as String?,
      ),
      recommendedVersion: json['recommendedVersion'] != null
          ? RecommendedVersionInfo.fromJson(
              json['recommendedVersion'] as Map<String, dynamic>,
            )
          : null,
      message: json['message'] as String,
      currentVersion: json['currentVersion'] as String,
      currentBuildNumber: json['currentBuildNumber'] as int,
      serverTimestamp: DateTime.parse(json['serverTimestamp'] as String),
    );
  }

  /// Версия заблокирована — требуется принудительное обновление.
  bool get isForceUpdateRequired =>
      isBlocked || status == ResponseStatus.blocked;

  /// Доступно обновление.
  bool get isUpdateAvailable => status == ResponseStatus.updateAvailable;

  /// Версия актуальна, обновлений нет.
  bool get isUpToDate => status == ResponseStatus.active;

  /// Ошибка при проверке.
  bool get isError => status == ResponseStatus.error;

  @override
  String toString() =>
      'CheckResponse(status: ${status.name}, '
      'v$currentVersion+$currentBuildNumber)';
}
