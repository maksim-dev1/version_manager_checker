import 'package:flutter/material.dart';

import '../checker.dart';
import '../models/check_response.dart';
import '../models/checker_exception.dart';
import 'blocked_screen.dart';
import 'update_bottom_sheet.dart';

/// Состояние проверки версии.
sealed class VersionCheckState {
  const VersionCheckState();
}

/// Проверка в процессе.
class VersionCheckLoading extends VersionCheckState {
  const VersionCheckLoading();
}

/// Проверка завершена успешно.
class VersionCheckCompleted extends VersionCheckState {
  final CheckResponse response;
  const VersionCheckCompleted(this.response);
}

/// Ошибка при проверке.
class VersionCheckError extends VersionCheckState {
  final Object error;
  const VersionCheckError(this.error);
}

/// Виджет-обёртка для автоматической проверки версии при запуске.
///
/// Оборачивает дочерний виджет и при первом построении выполняет
/// проверку версии. В зависимости от результата:
///
/// - **Заблокирована** — показывает [BlockedScreen] или пользовательский виджет
/// - **Доступно обновление** — показывает bottom sheet или пользовательский виджет
/// - **Актуальна** — показывает [child]
/// - **Ошибка** — показывает [child] (graceful degradation)
///
/// ## Пример
///
/// ```dart
/// VersionCheckerBuilder(
///   child: MyHomePage(),
///   // Опционально: кастомные обработчики
///   onBlocked: (context, response) => MyBlockedScreen(response: response),
///   onUpdateAvailable: (context, response) {
///     showUpdateBottomSheet(context: context, response: response);
///   },
/// );
/// ```
class VersionCheckerBuilder extends StatefulWidget {
  /// Основной виджет приложения.
  final Widget child;

  /// Виджет для отображения во время проверки.
  /// По умолчанию показывает [child].
  final Widget? loadingWidget;

  /// Билдер для состояния "версия заблокирована".
  /// Если не задан, показывает стандартный [BlockedScreen].
  final Widget Function(BuildContext context, CheckResponse response)?
  blockedBuilder;

  /// Callback при обнаружении доступного обновления.
  /// Если не задан, показывает стандартный bottom sheet.
  final void Function(BuildContext context, CheckResponse response)?
  onUpdateAvailable;

  /// Callback при ошибке проверки.
  /// По умолчанию ошибки игнорируются (graceful degradation).
  final void Function(BuildContext context, Object error)? onError;

  /// Выполнять ли проверку.
  /// По умолчанию `true`.
  final bool enabled;

  /// Показывать ли индикатор загрузки во время проверки.
  /// По умолчанию `false` — показывает [child] сразу.
  final bool showLoadingIndicator;

  /// Билдер для произвольного управления состоянием.
  /// Если задан, перекрывает все остальные обработчики.
  final Widget Function(
    BuildContext context,
    VersionCheckState state,
    Widget child,
  )?
  builder;

  const VersionCheckerBuilder({
    super.key,
    required this.child,
    this.loadingWidget,
    this.blockedBuilder,
    this.onUpdateAvailable,
    this.onError,
    this.enabled = true,
    this.showLoadingIndicator = false,
    this.builder,
  });

  @override
  State<VersionCheckerBuilder> createState() => _VersionCheckerBuilderState();
}

class _VersionCheckerBuilderState extends State<VersionCheckerBuilder> {
  VersionCheckState _state = const VersionCheckLoading();

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _performCheck();
    }
  }

  Future<void> _performCheck() async {
    if (!VersionChecker.isInitialized) {
      setState(
        () => _state = const VersionCheckError(NotInitializedException()),
      );
      return;
    }

    final checker = VersionChecker.instance;

    // Если initialize() уже совершал попытку (успешную или нет) — не дублируем запрос.
    if (checker.checkAttempted) {
      final response = checker.lastResponse;
      if (response != null) {
        setState(() => _state = VersionCheckCompleted(response));
        _handleResponse(response);
      } else {
        // init-проверка уже упала — показываем child (graceful degradation)
        setState(() => _state = VersionCheckError(checker.lastCheckError ?? Exception('check failed')));
        if (checker.lastCheckError != null) {
          widget.onError?.call(context, checker.lastCheckError!);
        }
      }
      return;
    }

    try {
      final response = await checker.check();

      if (!mounted) return;

      setState(() => _state = VersionCheckCompleted(response));

      // Обработка результата
      _handleResponse(response);
    } catch (e) {
      if (!mounted) return;

      setState(() => _state = VersionCheckError(e));

      widget.onError?.call(context, e);
    }
  }

  void _handleResponse(CheckResponse response) {
    if (!mounted) return;

    // Блокировка обрабатывается через builder
    if (response.isForceUpdateRequired) return;

    // Доступно обновление
    if (response.isUpdateAvailable) {
      _showUpdatePrompt(response);
    }
  }

  Future<void> _showUpdatePrompt(CheckResponse response) async {
    // Проверяем частоту показа
    final shouldShow = await VersionChecker.instance.shouldShowUpdatePrompt(
      response,
    );

    if (!shouldShow || !mounted) return;

    if (widget.onUpdateAvailable != null) {
      widget.onUpdateAvailable!(context, response);
    } else {
      // Стандартный bottom sheet
      showUpdateBottomSheet(context: context, response: response);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Кастомный builder перекрывает всё
    if (widget.builder != null) {
      return widget.builder!(context, _state, widget.child);
    }

    return switch (_state) {
      VersionCheckLoading() =>
        widget.showLoadingIndicator
            ? (widget.loadingWidget ?? _defaultLoading())
            : widget.child,
      VersionCheckCompleted(response: final response) =>
        response.isForceUpdateRequired
            ? (widget.blockedBuilder?.call(context, response) ??
                  BlockedScreen(response: response))
            : widget.child,
      VersionCheckError() => widget.child,
    };
  }

  Widget _defaultLoading() {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
