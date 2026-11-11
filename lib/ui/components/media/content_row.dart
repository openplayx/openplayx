import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../tokens/app_spacing.dart';

/// A readable media/source row with a full keyboard-accessible action target.
class ContentRow extends StatelessWidget {
  const ContentRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.contentPadding,
    this.dense = false,
  });
  final Widget title;
  final Widget? subtitle, leading, trailing;
  final VoidCallback? onTap;

  /// Secondary action, e.g. editing; long press (or long click on desktop).
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? contentPadding;
  final bool dense;
  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle(
          style: theme.textTheme.small.copyWith(
            color: theme.colorScheme.foreground,
          ),
          child: title,
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: DefaultTextStyle(
              style: theme.textTheme.muted.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
              child: subtitle!,
            ),
          ),
      ],
    );
    return Padding(
      padding:
          contentPadding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
      child: LayoutBuilder(
        builder: (context, box) {
          final primary = Semantics(
            button: onTap != null || onLongPress != null,
            child: Material(
              color: theme.colorScheme.card,
              borderRadius: theme.radius,
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: theme.radius,
                hoverColor: theme.colorScheme.accent,
                focusColor: theme.colorScheme.accent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                      horizontal: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: AppSpacing.md),
                        ],
                        Expanded(child: text),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          if (trailing == null) return primary;
          if (box.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(16) > 24) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                primary,
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: trailing!,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: primary),
              trailing!,
            ],
          );
        },
      ),
    );
  }
}
