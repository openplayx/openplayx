import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../capabilities/sources/source_manager.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/components/settings/settings_section.dart';
import 'scan_extensions_page.dart';

/// Global file-suffix filter used by both preview scans and library scans.
///
/// The row shows the current list; editing happens on [ScanExtensionsPage].
class ScanExtensionsRow extends StatefulWidget with SettingsRowContent {
  const ScanExtensionsRow({super.key, required this.sources});
  final SourceManager sources;
  @override
  State<ScanExtensionsRow> createState() => _ScanExtensionsRowState();
}

class _ScanExtensionsRowState extends State<ScanExtensionsRow> {
  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'ScanExtensionsPage'),
        builder: (_) => ScanExtensionsPage(sources: widget.sources),
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final values = widget.sources.scanExtensions;
    return SettingsRow(
      key: const ValueKey('scan-extensions'),
      title: l.scanExtensions,
      chevron: true,
      onTap: _edit,
      control: Text(
        values.isEmpty ? '*' : values.join(', '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: ShadTheme.of(context).textTheme.muted.copyWith(fontSize: 14),
      ),
    );
  }
}
