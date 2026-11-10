import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/sources/source_config.dart';
import '../../data/sources/source_manager.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/components/settings/settings_section.dart';

/// Global file-suffix filter used by both preview scans and library scans.
class ScanExtensionsRow extends StatefulWidget {
  const ScanExtensionsRow({super.key, required this.sources});
  final SourceManager sources;
  @override
  State<ScanExtensionsRow> createState() => _ScanExtensionsRowState();
}

class _ScanExtensionsRowState extends State<ScanExtensionsRow> {
  late final _controller = TextEditingController(
    text: widget.sources.scanExtensions.join(', '),
  );
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final values = parseScanExtensions(_controller.text);
      await widget.sources.setScanExtensions(values);
      if (mounted) _controller.text = values.join(', ');
    } catch (_) {
      if (mounted) _failed = true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          title: l.scanExtensions,
          description: l.scanExtensionsHelp,
          control: SizedBox(
            width: 280,
            child: ShadInput(
              controller: _controller,
              enabled: !_busy,
              autocorrect: false,
              enableSuggestions: false,
              placeholder: const Text('mp4, mkv, avi'),
              onSubmitted: (_) => _save(),
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: ShadButton.outline(
            onPressed: _busy ? null : _save,
            enabled: !_busy,
            child: Text(l.save),
          ),
        ),
        if (_failed) ShadAlert.destructive(title: Text(l.preferenceSaveFailed)),
      ],
    );
  }
}
