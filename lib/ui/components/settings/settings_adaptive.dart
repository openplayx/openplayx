import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../adaptive/app_page.dart';
import '../../icons/app_icons.dart';
import '../../tokens/app_metrics.dart';
import '../../tokens/app_spacing.dart';
import 'settings_section.dart';

/// Phones get full-screen pages and bottom action sheets; wider windows keep
/// anchored menus and centered dialogs.
bool isCompactSettings(BuildContext context) =>
    MediaQuery.sizeOf(context).width < AppMetrics.compactBreakpoint;

/// One button in a [showSettingsActionSheet].
class SettingsSheetAction {
  const SettingsSheetAction(
    this.label,
    this.onSelected, {
    this.destructive = false,
    this.selected = false,
  });
  final String label;
  final VoidCallback onSelected;
  final bool destructive, selected;
}

/// Bottom action sheet: an optional title/message, the actions, and a
/// separate cancel button, all within thumb reach.
Future<void> showSettingsActionSheet(
  BuildContext context, {
  required List<SettingsSheetAction> actions,
  String? title,
  String? message,
}) async {
  final selected = await showModalBottomSheet<SettingsSheetAction>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (c) {
      final theme = ShadTheme.of(c);
      final colors = theme.colorScheme;
      Widget block(List<Widget> children) => DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: colors.border),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      );
      Widget button(
        String label, {
        required VoidCallback onTap,
        Color? color,
        bool bold = false,
        bool check = false,
      }) => InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.large.copyWith(
                    fontSize: 17,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                    color: color ?? colors.primary,
                  ),
                ),
              ),
              if (check) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(AppIcons.check, size: 18, color: colors.primary),
              ],
            ],
          ),
        ),
      );
      final divider = Divider(height: 1, thickness: 1, color: colors.border);
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          0,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: block([
                  if (title != null || message != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Column(
                        children: [
                          if (title != null)
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.small.copyWith(
                                color: colors.mutedForeground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (message != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.muted,
                            ),
                          ],
                        ],
                      ),
                    ),
                    divider,
                  ],
                  for (final (i, action) in actions.indexed) ...[
                    if (i > 0) divider,
                    button(
                      action.label,
                      onTap: () => Navigator.pop(c, action),
                      color: action.destructive ? colors.destructive : null,
                      check: action.selected,
                    ),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            block([
              button(
                MaterialLocalizations.of(c).cancelButtonLabel,
                onTap: () => Navigator.pop(c),
                bold: true,
              ),
            ]),
          ],
        ),
      );
    },
  );
  selected?.onSelected();
}

/// Asks before a consequential action. Phones get an action sheet, wider
/// windows a dialog. Resolves to true only when confirmed.
Future<bool> showSettingsConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  if (isCompactSettings(context)) {
    var confirmed = false;
    await showSettingsActionSheet(
      context,
      title: title,
      message: message,
      actions: [
        SettingsSheetAction(
          confirmLabel,
          () => confirmed = true,
          destructive: destructive,
        ),
      ],
    );
    return confirmed;
  }
  final result = await showShadDialog<bool>(
    context: context,
    builder: (c) => ShadDialog(
      title: Text(title),
      description: Text(message),
      actions: [
        ShadButton.ghost(
          onPressed: () => Navigator.pop(c, false),
          child: Text(cancelLabel),
        ),
        destructive
            ? ShadButton.destructive(
                onPressed: () => Navigator.pop(c, true),
                child: Text(confirmLabel),
              )
            : ShadButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(confirmLabel),
              ),
      ],
    ),
  );
  return result == true;
}

/// Full-screen settings page pushed from a row; [trailing] goes in the
/// header (e.g. a Save button).
Future<T?> pushSettingsPage<T>(
  BuildContext context, {
  required String title,
  required List<Widget> Function(BuildContext context) children,
  List<Widget> Function(BuildContext context)? trailing,
}) => Navigator.of(context).push<T>(
  MaterialPageRoute(
    builder: (c) => AppPage(
      title: Text(title),
      trailing: trailing?.call(c) ?? const [],
      body: SettingsListView(children: children(c)),
    ),
  ),
);

/// Full-screen single choice list; pops with the picked value.
class SettingsChoicePage<T> extends StatelessWidget {
  const SettingsChoicePage({
    super.key,
    required this.title,
    required this.value,
    required this.options,
  });
  final String title;
  final T value;
  final Map<T, String> options;
  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    return AppPage(
      title: Text(title),
      body: SettingsListView(
        children: [
          SettingsSection(
            children: [
              for (final option in options.entries)
                SettingsRow(
                  key: ValueKey('choice-${option.key}'),
                  title: option.value,
                  control: option.key == value
                      ? Icon(AppIcons.check, size: 20, color: colors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, option.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full-screen single text field with Save in the header.
class SettingsInputPage extends StatefulWidget {
  const SettingsInputPage({
    super.key,
    required this.title,
    required this.initial,
    required this.saveLabel,
    this.description,
    this.placeholder,
    this.keyboardType,
    this.validate,
  });
  final String title, initial, saveLabel;
  final String? description, placeholder;
  final TextInputType? keyboardType;
  final String? Function(String value)? validate;
  @override
  State<SettingsInputPage> createState() => _SettingsInputPageState();
}

class _SettingsInputPageState extends State<SettingsInputPage> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final message = widget.validate?.call(_controller.text);
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: Text(widget.title),
    trailing: [
      ShadButton.ghost(
        key: const ValueKey('settings-input-save'),
        onPressed: _submit,
        child: Text(widget.saveLabel),
      ),
    ],
    body: SettingsListView(
      children: [
        SettingsSection(
          footer: _error ?? widget.description,
          children: [
            ShadInput(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: widget.keyboardType,
              placeholder: widget.placeholder == null
                  ? null
                  : Text(widget.placeholder!),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ],
    ),
  );
}
