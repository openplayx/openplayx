import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../capabilities/sources/source_manager.dart';
import '../../data/sources/source_config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/forms/form_actions.dart';
import '../../ui/components/forms/settings_text_input.dart';
import '../../ui/components/settings/settings_section.dart';
import '../../ui/icons/app_icons.dart';
import '../../ui/tokens/app_spacing.dart';

final _validExtension = RegExp(r'^[a-z0-9]{1,16}$');

/// Picks the global scan suffixes: toggle chips for common video and audio
/// types, removable chips for custom ones, and Save at the bottom.
///
/// Pops `true` once the new list is saved.
class ScanExtensionsPage extends StatefulWidget {
  const ScanExtensionsPage({super.key, required this.sources});
  final SourceManager sources;
  @override
  State<ScanExtensionsPage> createState() => _ScanExtensionsPageState();
}

class _ScanExtensionsPageState extends State<ScanExtensionsPage> {
  late Set<String> _selected = {...widget.sources.scanExtensions};
  late List<String> _custom = _customOf(_selected);
  final _input = TextEditingController();
  String? _inputError;
  bool _busy = false;
  bool _failed = false;

  static List<String> _customOf(Iterable<String> values) => [
    for (final e in values)
      if (!scanExtensionVideoPresets.contains(e) &&
          !scanExtensionAudioPresets.contains(e))
        e,
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _toggle(String extension) => setState(() {
    if (!_selected.remove(extension)) _selected.add(extension);
  });

  void _setAll(List<String> group, bool on) => setState(() {
    on ? _selected.addAll(group) : _selected.removeAll(group);
  });

  void _add() {
    final l = AppLocalizations.of(context);
    final values = parseScanExtensions(_input.text);
    if (values.isEmpty) return;
    if (values.any((e) => !_validExtension.hasMatch(e))) {
      setState(() => _inputError = l.scanExtensionsInvalid);
      return;
    }
    setState(() {
      _inputError = null;
      _input.clear();
      _selected.addAll(values);
      for (final e in _customOf(values)) {
        if (!_custom.contains(e)) _custom.add(e);
      }
    });
  }

  void _removeCustom(String extension) => setState(() {
    _custom.remove(extension);
    _selected.remove(extension);
  });

  void _restoreDefaults() => setState(() {
    _selected = {...defaultScanExtensions};
    _custom = _customOf(_selected);
    _inputError = null;
    _failed = false;
  });

  /// Presets first, in their listed order, then custom ones.
  List<String> get _ordered => [
    for (final e in [
      ...scanExtensionVideoPresets,
      ...scanExtensionAudioPresets,
      ..._custom,
    ])
      if (_selected.contains(e)) e,
  ];

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.sources.setScanExtensions(_ordered);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _group(String title, List<String> presets) {
    final l = AppLocalizations.of(context);
    final count = presets.where(_selected.contains).length;
    final all = count == presets.length;
    return SettingsSection(
      children: [
        SettingsRow(
          title: title,
          description: l.scanExtensionsSelected(count, presets.length),
          control: ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: () => _setAll(presets, !all),
            child: Text(
              all ? l.scanExtensionsSelectNone : l.scanExtensionsSelectAll,
            ),
          ),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final e in presets)
              _ExtensionChip(
                key: ValueKey('scan-ext-$e'),
                label: e,
                selected: _selected.contains(e),
                onTap: () => _toggle(e),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppPage(
      pageContext: const PageContextData(pageType: 'scan_extensions'),
      title: Text(l.scanExtensions),
      body: SettingsListView(
        children: [
          _group(l.scanExtensionsVideo, scanExtensionVideoPresets),
          _group(l.scanExtensionsAudio, scanExtensionAudioPresets),
          SettingsSection(
            footer: _selected.isEmpty
                ? '${l.scanExtensionsHelp}\n${l.scanExtensionsAllFiles}'
                : l.scanExtensionsHelp,
            children: [
              SettingsRow(title: l.scanExtensionsCustom),
              if (_custom.isNotEmpty)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final e in _custom)
                      _ExtensionChip(
                        key: ValueKey('scan-ext-$e'),
                        label: e,
                        selected: true,
                        onRemove: () => _removeCustom(e),
                        removeLabel: l.scanExtensionsRemove(e),
                      ),
                  ],
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.sm,
                children: [
                  Row(
                    spacing: AppSpacing.sm,
                    children: [
                      Expanded(
                        child: SettingsTextInput(
                          key: const ValueKey('scan-ext-input'),
                          controller: _input,
                          example: l.scanExtensionsAddHint,
                          onSubmitted: (_) => _add(),
                        ),
                      ),
                      ShadButton.outline(
                        key: const ValueKey('scan-ext-add'),
                        leading: const Icon(AppIcons.add, size: 16),
                        onPressed: _add,
                        child: Text(l.add),
                      ),
                    ],
                  ),
                  if (_inputError != null)
                    Text(
                      _inputError!,
                      style: ShadTheme.of(context).textTheme.small.copyWith(
                        color: ShadTheme.of(context).colorScheme.destructive,
                      ),
                    ),
                ],
              ),
            ],
          ),
          FormActions(
            status: _failed ? FormStatus.error(l.preferenceSaveFailed) : null,
            [
              FormAction(
                l.scanExtensionsRestoreDefaults,
                _busy ? null : _restoreDefaults,
                key: const ValueKey('scan-ext-defaults'),
              ),
              FormAction.primary(
                l.save,
                _busy ? null : _save,
                key: const ValueKey('scan-ext-save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A pill for one extension: filled with a check when selected, outlined
/// when not; custom ones carry a remove button instead.
class _ExtensionChip extends StatelessWidget {
  const _ExtensionChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.onRemove,
    this.removeLabel,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap, onRemove;
  final String? removeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colors = theme.colorScheme;
    final fg = selected ? colors.primaryForeground : colors.foreground;
    final radius = BorderRadius.circular(999);
    final icon = onRemove != null
        ? AppIcons.close
        : selected
        ? AppIcons.check
        : null;
    final body = Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: EdgeInsetsDirectional.only(
        start: AppSpacing.md,
        end: icon == null ? AppSpacing.md : AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: selected ? colors.primary : colors.background,
        borderRadius: radius,
        border: Border.all(color: selected ? colors.primary : colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xs,
        children: [
          Text(
            label,
            style: theme.textTheme.small.copyWith(
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (icon != null) Icon(icon, size: 14, color: fg),
        ],
      ),
    );
    if (onRemove != null) {
      return Semantics(
        button: true,
        label: removeLabel ?? label,
        excludeSemantics: true,
        child: InkWell(borderRadius: radius, onTap: onRemove, child: body),
      );
    }
    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(borderRadius: radius, onTap: onTap, child: body),
    );
  }
}
