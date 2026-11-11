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

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ShadTheme.of(context).colorScheme.background,
      border: Border(
        top: BorderSide(color: ShadTheme.of(context).colorScheme.border),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final destination in AppDestination.values)
              Expanded(
                child: _NavigationItem(
                  destination: destination,
                  selected: selected == destination.index,
                  bottom: true,
                  onPressed: () => onSelected(destination.index),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.onPressed,
    this.compact = false,
    this.bottom = false,
  });
  final AppDestination destination;
  final bool selected, compact, bottom;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final label = destination.label(context);
    final content = bottom
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(destination.icon, size: 20),
              const SizedBox(height: AppSpacing.xs),
              Text(label, textAlign: TextAlign.center),
              if (selected)
                Container(
                  width: 16,
                  height: 3,
                  margin: const EdgeInsets.only(top: 4),
                  color: theme.colorScheme.primary,
                ),
            ],
          )
        : Row(
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
          height: bottom
              ? 56 + MediaQuery.textScalerOf(context).scale(14) * 2
              : AppMetrics.touchTarget,
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
