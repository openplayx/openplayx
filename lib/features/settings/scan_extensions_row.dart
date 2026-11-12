import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/sources/source_config.dart';
import '../../data/sources/source_manager.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/components/settings/settings_section.dart';

/// Global file-suffix filter used by both preview scans and library scans.
///
/// The row shows the current list; editing happens in a dialog.
class ScanExtensionsRow extends StatefulWidget with SettingsRowContent {
  const ScanExtensionsRow({super.key, required this.sources});
  final SourceManager sources;
  @override
  State<ScanExtensionsRow> createState() => _ScanExtensionsRowState();
}

class _ScanExtensionsRowState extends State<ScanExtensionsRow> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _edit() async {
    final l = AppLocalizations.of(context);
    final text = await showSettingsInputDialog(
      context,
      title: l.scanExtensions,
      description: l.scanExtensionsHelp,
      initial: widget.sources.scanExtensions.join(', '),
      placeholder: 'mp4, mkv, avi',
      cancelLabel: l.cancel,
      saveLabel: l.save,
      validate: (value) {
        try {
          parseScanExtensions(value);
          return null;
        } catch (_) {
          return l.preferenceSaveFailed;
        }
      },
    );
    if (text == null || !mounted) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.sources.setScanExtensions(parseScanExtensions(text));
    } catch (_) {
      _failed = true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final values = widget.sources.scanExtensions;
    return SettingsRow(
      key: const ValueKey('scan-extensions'),
      title: l.scanExtensions,
      description: _failed ? l.preferenceSaveFailed : null,
      chevron: true,
      onTap: _busy ? null : _edit,
      control: Text(
        values.isEmpty ? '*' : values.join(', '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: ShadTheme.of(context).textTheme.muted.copyWith(fontSize: 14),
      ),
    );
  }
}
