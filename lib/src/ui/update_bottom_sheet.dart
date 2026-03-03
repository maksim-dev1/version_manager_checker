import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../checker.dart';
import '../models/check_response.dart';
import '../models/enums.dart';
import '../models/store_link_info.dart';

/// Показывает bottom sheet с предложением обновления.
///
/// Автоматически управляет частотой показа через [VersionChecker].
///
/// ```dart
/// if (response.isUpdateAvailable) {
///   showUpdateBottomSheet(context: context, response: response);
/// }
/// ```
Future<bool?> showUpdateBottomSheet({
  required BuildContext context,
  required CheckResponse response,
  String? title,
  String? updateButtonText,
  String? laterButtonText,
  bool isDismissible = true,
  VoidCallback? onUpdate,
  VoidCallback? onLater,
}) {
  final recommended = response.recommendedVersion;
  if (recommended == null) return Future.value(null);

  // Отмечаем показ
  if (VersionChecker.isInitialized) {
    VersionChecker.instance.markPromptShown(recommended.versionNumber);
  }

  return showModalBottomSheet<bool>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _UpdateBottomSheetContent(
      response: response,
      title: title,
      updateButtonText: updateButtonText,
      laterButtonText: laterButtonText,
      isDismissible: isDismissible,
      onUpdate: onUpdate,
      onLater: onLater,
    ),
  );
}

class _UpdateBottomSheetContent extends StatelessWidget {
  final CheckResponse response;
  final String? title;
  final String? updateButtonText;
  final String? laterButtonText;
  final bool isDismissible;
  final VoidCallback? onUpdate;
  final VoidCallback? onLater;

  const _UpdateBottomSheetContent({
    required this.response,
    this.title,
    this.updateButtonText,
    this.laterButtonText,
    this.isDismissible = true,
    this.onUpdate,
    this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recommended = response.recommendedVersion!;
    final storeLinks = recommended.storeLinks;
    final priority = response.updatePriority;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Индикатор drag
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Иконка приоритета
            _PriorityBadge(priority: priority),
            const SizedBox(height: 16),

            // Заголовок
            Text(
              title ?? _defaultTitle(priority),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Версия
            Text(
              'v${recommended.versionNumber}+${recommended.buildNumber}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Сообщение
            Text(
              response.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            // Changelog
            if (recommended.changelog.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Что нового:',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recommended.changelog,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Кнопка обновления
            if (storeLinks.isNotEmpty)
              ...storeLinks.map(
                (link) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: onUpdate ?? () => _openStore(context, link),
                      child: Text(
                        updateButtonText ?? 'Обновить в ${link.storeName}',
                      ),
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: onUpdate,
                  child: Text(updateButtonText ?? 'Обновить'),
                ),
              ),

            // Кнопка "Позже"
            if (isDismissible) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () {
                    if (VersionChecker.isInitialized) {
                      VersionChecker.instance.markPromptDismissed(
                        recommended.versionNumber,
                      );
                    }
                    onLater?.call();
                    Navigator.of(context).pop(false);
                  },
                  child: Text(laterButtonText ?? 'Позже'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _defaultTitle(UpdatePriority? priority) {
    return switch (priority) {
      UpdatePriority.critical => 'Критическое обновление',
      UpdatePriority.high => 'Важное обновление',
      UpdatePriority.medium => 'Доступно обновление',
      UpdatePriority.low => 'Есть обновление',
      null => 'Доступно обновление',
    };
  }

  Future<void> _openStore(BuildContext context, StoreLinkInfo link) async {
    final uri = Uri.parse(link.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Бейдж приоритета обновления.
class _PriorityBadge extends StatelessWidget {
  final UpdatePriority? priority;

  const _PriorityBadge({this.priority});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (IconData icon, Color color) = switch (priority) {
      UpdatePriority.critical => (Icons.error, colorScheme.error),
      UpdatePriority.high => (Icons.warning_amber, Colors.orange),
      UpdatePriority.medium => (Icons.info, colorScheme.primary),
      UpdatePriority.low => (Icons.update, colorScheme.tertiary),
      null => (Icons.update, colorScheme.primary),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 40, color: color),
    );
  }
}
