import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/check_response.dart';
import '../models/store_link_info.dart';

/// Полноэкранный экран блокировки при критическом обновлении.
///
/// Показывается когда версия заблокирована и пользователь
/// обязан обновить приложение для продолжения работы.
///
/// ```dart
/// if (response.isForceUpdateRequired) {
///   Navigator.of(context).pushReplacement(
///     MaterialPageRoute(
///       builder: (_) => BlockedScreen(response: response),
///     ),
///   );
/// }
/// ```
class BlockedScreen extends StatelessWidget {
  /// Ответ сервера с информацией о блокировке.
  final CheckResponse response;

  /// Заголовок экрана.
  /// По умолчанию: "Требуется обновление".
  final String? title;

  /// Иконка в центре экрана.
  final IconData icon;

  /// Цвет иконки.
  final Color? iconColor;

  /// Текст кнопки обновления.
  /// По умолчанию: "Обновить".
  final String? updateButtonText;

  /// Callback при нажатии на кнопку обновления.
  /// Если не задан, открывает ссылку на магазин.
  final VoidCallback? onUpdatePressed;

  const BlockedScreen({
    super.key,
    required this.response,
    this.title,
    this.icon = Icons.system_update,
    this.iconColor,
    this.updateButtonText,
    this.onUpdatePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final recommended = response.recommendedVersion;
    final storeLinks = recommended?.storeLinks ?? [];

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Иконка
                Icon(icon, size: 80, color: iconColor ?? colorScheme.error),
                const SizedBox(height: 24),

                // Заголовок
                Text(
                  title ?? 'Требуется обновление',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Сообщение от сервера
                Text(
                  response.message,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Причина блокировки
                if (response.blockReason != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            response.blockReason!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Changelog
                if (recommended?.changelog != null &&
                    recommended!.changelog.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Что нового в v${recommended.versionNumber}:',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      recommended.changelog,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],

                const Spacer(flex: 3),

                // Кнопки обновления
                if (storeLinks.isNotEmpty)
                  ...storeLinks.map(
                    (link) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: onUpdatePressed ?? () => _openStore(link),
                          icon: Icon(_storeIcon(link.storeName)),
                          label: Text(
                            updateButtonText ?? 'Обновить в ${link.storeName}',
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: onUpdatePressed,
                      child: Text(updateButtonText ?? 'Обновить'),
                    ),
                  ),

                const SizedBox(height: 16),

                // Версия
                Text(
                  'Текущая версия: '
                  'v${response.currentVersion}+${response.currentBuildNumber}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _storeIcon(String storeName) {
    final name = storeName.toLowerCase();
    if (name.contains('app store') || name.contains('apple')) {
      return Icons.apple;
    }
    if (name.contains('google') || name.contains('play')) {
      return Icons.shop;
    }
    return Icons.open_in_new;
  }

  Future<void> _openStore(StoreLinkInfo link) async {
    final uri = Uri.parse(link.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
