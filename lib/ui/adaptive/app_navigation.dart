import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/app_destination.dart';
import '../tokens/app_metrics.dart';
import '../tokens/app_spacing.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.compact,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      width: compact ? 80 : 208,
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: BorderDirectional(
          end: BorderSide(color: theme.colorScheme.border),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                compact ? 'OPX' : 'OpenPlayX',
                textAlign: TextAlign.center,
                style: theme.textTheme.h4,
              ),
            ),
            for (final destination in AppDestination.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _NavigationItem(
                  destination: destination,
                  selected: selected == destination.index,
                  compact: compact,
                  onPressed: () => onSelected(destination.index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Floating capsule tab bar for phones (the sidebar takes over at 600pt+).
/// Metrics follow the reference design: 21pt side margins, a 62pt frosted
/// capsule hovering 12pt above the home indicator, and a 4pt-inset pill
/// marking the selected tab.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;

  static const _margin = 21.0;
  static const _inset = 4.0;
  static const _height = 62.0;
  static const _label = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final dark = ShadTheme.of(context).brightness == Brightness.dark;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    final scale = MediaQuery.textScalerOf(context);
    // Grow with larger text so labels never clip.
    final height = _height + (scale.scale(_label) - _label) * 1.4;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _margin,
        AppSpacing.sm,
        _margin,
        safe > 0 ? (safe - 12).clamp(12, double.infinity) : 12,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.4 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipPath(
          clipper: const ShapeBorderClipper(shape: StadiumBorder()),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: height,
              padding: const EdgeInsets.all(_inset),
              decoration: ShapeDecoration(
                color: colors.card.withValues(alpha: 0.82),
                shape: StadiumBorder(
                  side: BorderSide(
                    color: colors.foreground.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  for (final destination in AppDestination.values)
                    Expanded(
                      child: _BottomItem(
                        destination: destination,
                        selected: selected == destination.index,
                        onPressed: () => onSelected(destination.index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });
  final AppDestination destination;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    return Semantics(
      key: ValueKey('nav-${destination.name}'),
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: selected
                ? colors.foreground.withValues(alpha: 0.08)
                : colors.foreground.withValues(alpha: 0),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(destination.icon, size: 24, color: colors.foreground),
              const SizedBox(height: 3),
              Text(
                destination.label(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppBottomBar._label,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.onPressed,
    this.compact = false,
  });
  final AppDestination destination;
  final bool selected, compact;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final label = destination.label(context);
    final content = Row(
      mainAxisAlignment: compact
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Icon(destination.icon, size: 20),
        if (!compact) ...[
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label)),
        ],
      ],
    );
    return Semantics(
      key: ValueKey('nav-${destination.name}'),
      selected: selected,
      button: true,
      label: compact ? label : null,
      child: Tooltip(
        message: compact ? label : '',
        child: ShadButton.ghost(
          width: double.infinity,
          expands: true,
          height: AppMetrics.touchTarget,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          backgroundColor: selected ? theme.colorScheme.accent : null,
          foregroundColor: selected ? theme.colorScheme.accentForeground : null,
          onPressed: onPressed,
          child: content,
        ),
      ),
    );
  }
}
