import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/icons/app_icons.dart';
import '../../ui/tokens/app_metrics.dart';
import '../../ui/tokens/app_spacing.dart';

/// A compact source row. The primary target and its actions never overlap.
class SourceListRow extends StatelessWidget {
  const SourceListRow({
    super.key,
    required this.title,
    required this.leading,
    required this.subtitle,
    required this.actions,
    this.status,
    this.onTap,
    this.expanded,
  });

  final String title;
  final Widget leading, subtitle, actions;
  final Widget? status;
  final VoidCallback? onTap;
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 480 ||
            MediaQuery.textScalerOf(context).scale(16) > 24;
        return Row(
          children: [
            Expanded(
              child: Semantics(
                button: onTap != null,
                expanded: expanded,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: AppMetrics.controlRadius,
                    hoverColor: theme.colorScheme.accent,
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                        horizontal: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          leading,
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: theme.textTheme.small),
                                const SizedBox(height: AppSpacing.xs),
                                DefaultTextStyle(
                                  style: theme.textTheme.muted,
                                  child: subtitle,
                                ),
                                if (compact && status != null) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  status!,
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!compact && status != null) ...[
              const SizedBox(width: AppSpacing.md),
              Flexible(child: status!),
            ],
            actions,
          ],
        );
      },
    );
  }
}

class SourceRowAction {
  const SourceRowAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.key,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Key? key;
  final bool destructive;
}

/// The same discoverable menu for both connection and file-source actions.
class SourceActionsMenu extends StatefulWidget {
  const SourceActionsMenu({
    super.key,
    required this.label,
    required this.actions,
    this.enabled = true,
  });

  final String label;
  final List<SourceRowAction> actions;
  final bool enabled;

  @override
  State<SourceActionsMenu> createState() => _SourceActionsMenuState();
}

class _SourceActionsMenuState extends State<SourceActionsMenu> {
  final _buttonFocus = FocusNode();

  @override
  void dispose() {
    _buttonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.actions;
    final enabled = widget.enabled;
    final firstEnabled = actions.where((a) => a.onPressed != null).firstOrNull;
    final theme = ShadTheme.of(context);
    final colors = theme.colorScheme;
    return MenuAnchor(
      childFocusNode: _buttonFocus,
      alignmentOffset: const Offset(0, AppSpacing.xs),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.popover),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(6),
        side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppMetrics.controlRadius),
        ),
      ),
      menuChildren: [
        for (final action in actions) ...[
          if (action.destructive) const Divider(height: AppSpacing.sm),
          MenuItemButton(
            key: action.key,
            autofocus: action == firstEnabled,
            onPressed: enabled ? action.onPressed : null,
            leadingIcon: Icon(
              action.icon,
              size: 18,
              color: action.onPressed == null
                  ? colors.mutedForeground
                  : action.destructive
                  ? colors.destructive
                  : colors.popoverForeground,
            ),
            child: Text(
              action.label,
              style: theme.textTheme.small.copyWith(
                color: action.onPressed == null
                    ? colors.mutedForeground
                    : action.destructive
                    ? colors.destructive
                    : colors.popoverForeground,
              ),
            ),
          ),
        ],
      ],
      builder: (context, controller, _) => Tooltip(
        message: AppLocalizations.of(context).sourceActions(widget.label),
        child: ShadIconButton.ghost(
          focusNode: _buttonFocus,
          width: AppMetrics.touchTarget,
          height: AppMetrics.touchTarget,
          padding: const EdgeInsets.all(AppSpacing.md),
          icon: const Icon(AppIcons.more, size: 18),
          enabled: enabled,
          onPressed: !enabled
              ? null
              : () =>
                    controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    );
  }
}
