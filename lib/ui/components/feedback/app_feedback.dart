import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../icons/app_icons.dart';
import '../../tokens/app_semantic_colors.dart';

/// Single entry point for user-facing feedback (see design/ui
/// frontend_design_system.md §6.3):
/// - [AppAlert]: persistent, in-page message next to what it is about.
/// - [showAppToast]: transient overlay that dismisses itself.
///
/// Appearance shared by every alert / toast (border, padding, position,
/// duration, …) lives in `AppTheme` (`primary/destructiveAlertTheme`,
/// `primary/destructiveToastTheme`). Structure (icon, colour per kind,
/// title / description layout) lives here. Pages only pick a [FeedbackKind].
enum FeedbackKind { info, success, warning, error }

IconData feedbackIcon(FeedbackKind kind) => switch (kind) {
  FeedbackKind.info => AppIcons.info,
  FeedbackKind.success => AppIcons.success,
  FeedbackKind.warning => AppIcons.warning,
  FeedbackKind.error => AppIcons.error,
};

/// Accent colour of a non-error kind; `null` keeps the theme's default.
Color? _accent(BuildContext context, FeedbackKind kind) {
  final colors = AppSemanticColors.of(context);
  return switch (kind) {
    FeedbackKind.success => colors.success,
    FeedbackKind.warning => colors.warning,
    FeedbackKind.info || FeedbackKind.error => null,
  };
}

/// In-page alert. Stays until the page clears or replaces it.
class AppAlert extends StatelessWidget {
  const AppAlert({
    super.key,
    required this.title,
    this.description,
    this.action,
    this.kind = FeedbackKind.info,
  });

  const AppAlert.error({
    super.key,
    required this.title,
    this.description,
    this.action,
  }) : kind = FeedbackKind.error;

  /// Picks [FeedbackKind.error] or [FeedbackKind.success] from an outcome.
  const AppAlert.result({
    super.key,
    required this.title,
    required bool failed,
    this.description,
    this.action,
  }) : kind = failed ? FeedbackKind.error : FeedbackKind.success;

  final String title;
  final String? description;

  /// Optional control under the text, e.g. a retry button.
  final Widget? action;
  final FeedbackKind kind;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(feedbackIcon(kind));
    final titleText = Text(title);
    final body = description == null && action == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (description != null) Text(description!),
              if (action != null) ...[
                if (description != null) const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: action,
                ),
              ],
            ],
          );
    final alert = switch (kind) {
      FeedbackKind.error => ShadAlert.destructive(
        icon: icon,
        title: titleText,
        description: body,
      ),
      FeedbackKind.info => ShadAlert(
        icon: icon,
        title: titleText,
        description: body,
      ),
      FeedbackKind.success || FeedbackKind.warning => _accented(
        context,
        _accent(context, kind)!,
        icon,
        titleText,
        body,
      ),
    };
    return Semantics(liveRegion: true, child: alert);
  }

  Widget _accented(
    BuildContext context,
    Color color,
    Widget icon,
    Widget title,
    Widget? body,
  ) {
    final theme = ShadTheme.of(context);
    final base = theme.primaryAlertTheme;
    return ShadAlert(
      icon: icon,
      title: title,
      description: body,
      iconColor: color,
      titleStyle: base.titleStyle?.copyWith(color: color),
      descriptionStyle: base.descriptionStyle?.copyWith(color: color),
      decoration: ShadDecoration(
        border: ShadBorder.all(
          color: color,
          radius: theme.radius,
          padding: const EdgeInsets.all(16),
          width: 1,
        ),
      ),
    );
  }
}

/// Transient toast. Silently does nothing when no toaster is mounted
/// (e.g. in isolated widget tests).
void showAppToast(
  BuildContext context,
  String message, {
  FeedbackKind kind = FeedbackKind.info,
  String? description,
}) {
  final toaster = ShadToaster.maybeOf(context);
  if (toaster == null) return;
  final colors = ShadTheme.of(context).colorScheme;
  final iconColor = switch (kind) {
    FeedbackKind.error => colors.destructiveForeground,
    _ => _accent(context, kind) ?? colors.foreground,
  };
  final title = Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(feedbackIcon(kind), size: 16, color: iconColor),
      const SizedBox(width: 8),
      Flexible(child: Text(message)),
    ],
  );
  final details = description == null ? null : Text(description);
  toaster.show(
    kind == FeedbackKind.error
        ? ShadToast.destructive(title: title, description: details)
        : ShadToast(title: title, description: details),
  );
}
