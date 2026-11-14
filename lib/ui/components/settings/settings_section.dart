import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../forms/settings_text_input.dart';
import '../../icons/app_icons.dart';
import '../../tokens/app_metrics.dart';
import '../../tokens/app_spacing.dart';
import 'settings_adaptive.dart';

/// Hides [SettingsSection] headers below it, used when a sub-page already
/// shows the section name as its page title.
class SettingsHeaderScope extends InheritedWidget {
  const SettingsHeaderScope({
    super.key,
    required this.hidden,
    required super.child,
  });
  final bool hidden;
  static bool hiddenOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SettingsHeaderScope>()
          ?.hidden ??
      false;
  @override
  bool updateShouldNotify(SettingsHeaderScope old) => old.hidden != hidden;
}

/// Marks a widget that builds a [SettingsRow] itself, so [SettingsSection]
/// does not add its own padding around it.
mixin SettingsRowContent on Widget {}

/// Inset grouped list: a small muted header above a rounded block of rows
/// separated by hairlines.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    this.title,
    this.footer,
    required this.children,
  });
  final String? title;

  /// Small muted note under the block, for context that is not a setting.
  final String? footer;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colors = theme.colorScheme;
    final showHeader = title != null && !SettingsHeaderScope.hiddenOf(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: AppSpacing.lg,
            color: colors.border,
          ),
        );
      }
      rows.add(
        child is SettingsRow || child is SettingsRowContent
            ? child
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: child,
              ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              child: Text(title!, style: theme.textTheme.muted),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: AppMetrics.panelRadius,
              border: Border.all(color: colors.border),
            ),
            child: ClipRRect(
              borderRadius: AppMetrics.panelRadius,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rows,
                ),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.lg,
                end: AppSpacing.lg,
                top: AppSpacing.sm,
              ),
              child: Text(
                footer!,
                style: theme.textTheme.muted.copyWith(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// One line in a [SettingsSection]: optional icon and title on the leading
/// side, the value or control on the trailing side.
///
/// With [onTap] the whole row is tappable; [chevron] marks navigation.
/// [stacked] places a wide control (text field, button group) under the
/// title. Large text sizes always stack so nothing gets squeezed.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.description,
    this.control,
    this.icon,
    this.leading,
    this.onTap,
    this.chevron = false,
    this.stacked = false,
    this.destructive = false,
    this.accent = false,
  });
  final String title;
  final String? description;
  final Widget? control;
  final IconData? icon;

  /// A custom leading mark (e.g. a brand logo); takes precedence over [icon].
  final Widget? leading;
  final VoidCallback? onTap;
  final bool chevron, stacked, destructive;

  /// Colors the title as an action (primary color).
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colors = theme.colorScheme;
    final titleStyle = theme.textTheme.p.copyWith(
      height: 1.3,
      color: destructive
          ? colors.destructive
          : accent
          ? colors.primary
          : colors.foreground,
    );
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        if (description != null) ...[
          const SizedBox(height: 2),
          Text(
            description!,
            style: theme.textTheme.muted.copyWith(fontSize: 12, height: 1.35),
          ),
        ],
      ],
    );
    final trailing = control == null
        ? null
        : DefaultTextStyle.merge(
            style: theme.textTheme.p.copyWith(color: colors.mutedForeground),
            child: control!,
          );
    final chevronIcon = chevron
        ? Icon(AppIcons.next, size: 18, color: colors.mutedForeground)
        : null;
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    final mark =
        this.leading ??
        (icon == null ? null : Icon(icon, size: 20, color: colors.foreground));
    final leading = mark == null
        ? null
        : Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
            child: mark,
          );

    Widget body;
    if (trailing != null && (stacked || largeText)) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ?leading,
              Expanded(child: text),
              ?chevronIcon,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(alignment: AlignmentDirectional.centerStart, child: trailing),
        ],
      );
    } else {
      body = LayoutBuilder(
        builder: (context, box) => Row(
          children: [
            ?leading,
            Expanded(child: text),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.md),
              // Values size to their content but never take over the title.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth * 0.55),
                child: trailing,
              ),
            ],
            if (chevronIcon != null) ...[
              const SizedBox(width: AppSpacing.xs),
              chevronIcon,
            ],
          ],
        ),
      );
    }
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Align(alignment: AlignmentDirectional.centerStart, child: body),
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// iOS-style form row: the label on the left and a borderless text field
/// filling the rest, with optional help below. Stacks at large text sizes.
class SettingsFieldRow extends StatelessWidget with SettingsRowContent {
  const SettingsFieldRow({
    super.key,
    required this.title,
    required this.field,
    this.description,
  });
  final String title;

  /// Usually a [ShadInput] with [ShadDecoration.none].
  final Widget field;
  final String? description;

  static const labelWidth = 104.0;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final label = Text(
      title,
      style: theme.textTheme.p.copyWith(
        height: 1.3,
        color: theme.colorScheme.foreground,
      ),
    );
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (largeText) ...[
              const SizedBox(height: AppSpacing.xs),
              label,
              field,
            ] else
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    SizedBox(width: labelWidth, child: label),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: field),
                  ],
                ),
              ),
            if (description != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  description!,
                  style: theme.textTheme.muted.copyWith(
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Width-limited scrolling body shared by every settings page, so the root
/// page and its sub-pages line up.
class SettingsListView extends StatelessWidget {
  const SettingsListView({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
    padding: AppSpacing.page(context),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppMetrics.formWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ],
  );
}

/// An entry in a [SettingsMenuRow] menu.
class SettingsMenuItem {
  const SettingsMenuItem(
    this.label,
    this.onSelected, {
    this.selected = false,
    this.destructive = false,
  });
  final String label;
  final VoidCallback onSelected;
  final bool selected, destructive;
}

/// A row that opens a small menu anchored under its trailing value.
class SettingsMenuRow extends StatefulWidget with SettingsRowContent {
  const SettingsMenuRow({
    super.key,
    required this.title,
    required this.items,
    this.description,
    this.value,
    this.enabled = true,
  });
  final String title;
  final String? description;

  /// Current value shown in the primary color; a chevron when null.
  final String? value;
  final List<SettingsMenuItem> items;
  final bool enabled;
  @override
  State<SettingsMenuRow> createState() => _SettingsMenuRowState();
}

class _SettingsMenuRowState extends State<SettingsMenuRow> {
  final _menu = MenuController();
  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colors = theme.colorScheme;
    final value = widget.value;
    if (isCompactSettings(context)) {
      return SettingsRow(
        title: widget.title,
        description: widget.description,
        chevron: true,
        control: value == null ? null : Text(value),
        onTap: widget.enabled
            ? () => showSettingsActionSheet(
                context,
                title: widget.title,
                actions: [
                  for (final item in widget.items)
                    SettingsSheetAction(
                      item.label,
                      item.onSelected,
                      destructive: item.destructive,
                      selected: item.selected,
                    ),
                ],
              )
            : null,
      );
    }
    return SettingsRow(
      title: widget.title,
      description: widget.description,
      onTap: widget.enabled
          ? () => _menu.isOpen ? _menu.close() : _menu.open()
          : null,
      control: MenuAnchor(
        controller: _menu,
        alignmentOffset: const Offset(0, AppSpacing.xs),
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.popover),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(6),
          shadowColor: const WidgetStatePropertyAll(Color(0x33000000)),
          side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppMetrics.controlRadius),
          ),
        ),
        menuChildren: [
          for (final item in widget.items)
            MenuItemButton(
              onPressed: item.onSelected,
              trailingIcon: item.selected
                  ? Icon(AppIcons.check, size: 16, color: colors.primary)
                  : null,
              child: Text(
                item.label,
                style: theme.textTheme.p.copyWith(
                  color: item.destructive
                      ? colors.destructive
                      : colors.popoverForeground,
                ),
              ),
            ),
        ],
        child: value == null
            ? Icon(AppIcons.more, size: 18, color: colors.mutedForeground)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.p.copyWith(color: colors.primary),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    LucideIcons.chevronsUpDown,
                    size: 14,
                    color: colors.primary,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Picks one of [options]; the current one is shown as the row value.
class SettingsChoiceRow<T> extends StatelessWidget with SettingsRowContent {
  const SettingsChoiceRow({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.description,
    this.leading,
    this.enabled = true,
  });
  final String title;
  final String? description;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  /// Optional mark shown beside each option on the full-screen picker.
  final Widget Function(T option)? leading;
  final bool enabled;
  @override
  Widget build(BuildContext context) => !enabled
      ? SettingsRow(
          title: title,
          description: description,
          control: Text(options[value] ?? ''),
        )
      : isCompactSettings(context)
      ? SettingsRow(
          title: title,
          description: description,
          chevron: true,
          control: Text(options[value] ?? ''),
          onTap: () async {
            final picked = await Navigator.of(context).push<T>(
              MaterialPageRoute(
                builder: (_) => SettingsChoicePage<T>(
                  title: title,
                  value: value,
                  options: options,
                  leading: leading,
                ),
              ),
            );
            if (picked != null && picked != value) onChanged(picked);
          },
        )
      : SettingsMenuRow(
          title: title,
          description: description,
          value: options[value],
          items: [
            for (final option in options.entries)
              SettingsMenuItem(
                option.value,
                () => onChanged(option.key),
                selected: option.key == value,
              ),
          ],
        );
}

/// Edits one text value in a dialog; returns the new text, or null when
/// cancelled. [validate] returns an error message to keep the dialog open.
Future<String?> showSettingsInputDialog(
  BuildContext context, {
  required String title,
  required String initial,
  required String cancelLabel,
  required String saveLabel,
  String? description,
  String? placeholder,
  TextInputType? keyboardType,
  String? Function(String value)? validate,
}) {
  if (isCompactSettings(context)) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SettingsInputPage(
          title: title,
          initial: initial,
          saveLabel: saveLabel,
          description: description,
          placeholder: placeholder,
          keyboardType: keyboardType,
          validate: validate,
        ),
      ),
    );
  }
  final controller = TextEditingController(text: initial);
  String? error;
  return showShadDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) {
        void submit() {
          final message = validate?.call(controller.text);
          if (message != null) {
            setState(() => error = message);
            return;
          }
          Navigator.pop(c, controller.text);
        }

        return ShadDialog(
          title: Text(title),
          description: description == null ? null : Text(description),
          actions: [
            ShadButton.ghost(
              onPressed: () => Navigator.pop(c),
              child: Text(cancelLabel),
            ),
            ShadButton(onPressed: submit, child: Text(saveLabel)),
          ],
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsTextInput(
                  controller: controller,
                  autofocus: true,
                  keyboardType: keyboardType,
                  example: placeholder,
                  onSubmitted: (_) => submit(),
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    error!,
                    style: TextStyle(
                      color: ShadTheme.of(c).colorScheme.destructive,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}
