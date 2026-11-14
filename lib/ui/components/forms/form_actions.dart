import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../icons/app_icons.dart';
import '../../tokens/app_metrics.dart';
import '../../tokens/app_semantic_colors.dart';
import '../../tokens/app_spacing.dart';
import '../settings/settings_adaptive.dart';

/// How much weight one form action carries.
enum FormActionKind {
  /// Commits the form: save, add, import. One per form, solid.
  primary,

  /// Helps before committing: test connection. Outlined.
  secondary,

  /// Removes or clears something. Red text; confirm it before acting.
  destructive,
}

/// One button in a [FormActions] bar.
class FormAction {
  const FormAction(
    this.label,
    this.onPressed, {
    this.kind = FormActionKind.secondary,
    this.key,
  });

  const FormAction.primary(String label, VoidCallback? onPressed, {Key? key})
    : this(label, onPressed, kind: FormActionKind.primary, key: key);

  const FormAction.destructive(
    String label,
    VoidCallback? onPressed, {
    Key? key,
  }) : this(label, onPressed, kind: FormActionKind.destructive, key: key);

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final FormActionKind kind;
  final Key? key;
}

enum FormStatusKind { idle, busy, success, error }

/// What the last action of a [FormActions] bar is doing or did.
class FormStatus {
  const FormStatus._(this.kind, this.message);

  /// Nothing to report; the slot stays reserved so nothing moves later.
  static const idle = FormStatus._(FormStatusKind.idle, '');

  const FormStatus.busy(String message) : this._(FormStatusKind.busy, message);
  const FormStatus.success(String message)
    : this._(FormStatusKind.success, message);
  const FormStatus.error(String message)
    : this._(FormStatusKind.error, message);

  /// Success or error from an outcome.
  const FormStatus.result(String message, {required bool failed})
    : this._(failed ? FormStatusKind.error : FormStatusKind.success, message);

  final FormStatusKind kind;
  final String message;
}

/// The one action bar at the bottom of a form embedded in a page (a form
/// that has no header of its own). App-wide rule for commit buttons:
///
/// - commit (save / add / import) is a solid primary button;
/// - helper actions are outlined, destructive ones red text;
/// - a standalone page puts its commit in the header ([PageSubmitButton]),
///   an embedded form uses this bar, a dialog keeps cancel + save at its
///   bottom right;
/// - accent text rows in a list are for non-commit actions only (choose a
///   folder, search devices, re-check).
///
/// Results appear where the user acted, never pushing the buttons: pass
/// [status] for progress, test results and errors. A plain "saved" is a
/// toast (showAppToast), not a status. Page-wide states (load failed) stay
/// as an alert at the top of the page.
///
/// Desktop: one row, status on the left, buttons right-aligned, primary
/// last. Phone: full-width buttons stacked, primary on top, status below
/// them (so a long message never moves a button).
class FormActions extends StatelessWidget {
  const FormActions(this.actions, {super.key, this.status});

  final List<FormAction> actions;

  /// Null: the bar has no status slot. [FormStatus.idle]: an empty slot.
  final FormStatus? status;

  Widget _status(BuildContext context, FormStatus status) {
    final theme = ShadTheme.of(context);
    final color = switch (status.kind) {
      FormStatusKind.success => AppSemanticColors.of(context).success,
      FormStatusKind.error => theme.colorScheme.destructive,
      _ => theme.colorScheme.mutedForeground,
    };
    final icon = switch (status.kind) {
      FormStatusKind.idle => null,
      FormStatusKind.busy => SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      ),
      FormStatusKind.success => Icon(AppIcons.success, size: 16, color: color),
      FormStatusKind.error => Icon(AppIcons.error, size: 16, color: color),
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        key: const ValueKey('form-status'),
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          if (icon != null)
            Padding(padding: const EdgeInsets.only(top: 2), child: icon),
          Expanded(
            child: Text(
              status.message,
              style: theme.textTheme.small.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  static int _rank(FormActionKind kind) => switch (kind) {
    FormActionKind.destructive => 0,
    FormActionKind.secondary => 1,
    FormActionKind.primary => 2,
  };

  Widget _button(BuildContext context, FormAction a, {bool expand = false}) {
    final child = Text(a.label);
    final width = expand ? double.infinity : null;
    return switch (a.kind) {
      FormActionKind.primary => ShadButton(
        key: a.key,
        width: width,
        onPressed: a.onPressed,
        enabled: a.onPressed != null,
        child: child,
      ),
      FormActionKind.secondary => ShadButton.outline(
        key: a.key,
        width: width,
        onPressed: a.onPressed,
        enabled: a.onPressed != null,
        child: child,
      ),
      FormActionKind.destructive => ShadButton.ghost(
        key: a.key,
        width: width,
        foregroundColor: ShadTheme.of(context).colorScheme.destructive,
        onPressed: a.onPressed,
        enabled: a.onPressed != null,
        child: child,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final ordered = [...actions]
      ..sort((a, b) => _rank(a.kind).compareTo(_rank(b.kind)));
    final status = this.status;
    if (isCompactSettings(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          for (final a in ordered.reversed) _button(context, a, expand: true),
          if (status != null)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 20),
              child: _status(context, status),
            ),
        ],
      );
    }
    final buttons = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [for (final a in ordered) _button(context, a)],
    );
    if (status == null) {
      // Right-aligned whatever the parent's constraints.
      return Align(alignment: AlignmentDirectional.centerEnd, child: buttons);
    }
    // Top-aligned: a long message grows downward, the buttons stay put.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.lg,
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppMetrics.touchTarget,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _status(context, status),
            ),
          ),
        ),
        buttons,
      ],
    );
  }
}

/// The commit button in a standalone page's header (save / add / import):
/// always a solid primary button, the same in every page. While [busy] it
/// shows a spinner in place, so the page itself never shifts.
class PageSubmitButton extends StatelessWidget {
  const PageSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => ShadButton(
    onPressed: busy ? null : onPressed,
    enabled: !busy && onPressed != null,
    leading: busy
        ? SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ShadTheme.of(context).colorScheme.primaryForeground,
            ),
          )
        : null,
    child: Text(label),
  );
}
