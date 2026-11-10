import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/diagnostics/diagnostics_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/components/settings/settings_section.dart';

class DiagnosticsSection extends StatefulWidget {
  const DiagnosticsSection({super.key});
  @override
  State<DiagnosticsSection> createState() => _DiagnosticsSectionState();
}

class _DiagnosticsSectionState extends State<DiagnosticsSection> {
  bool? _enabled;
  bool _saving = false;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    DiagnosticsService.enabled().then((value) {
      if (mounted) setState(() => _enabled = value);
    });
  }

  Future<void> _save(bool value) async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await DiagnosticsService.setEnabled(value);
      if (mounted) setState(() => _enabled = value);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SettingsSection(
      title: l.diagnosticsTitle,
      children: [
        SettingsRow(
          title: l.diagnosticsTitle,
          description: l.diagnosticsDescription,
          control: ShadSwitch(
            value: _enabled ?? false,
            onChanged: _enabled == null || _saving ? null : _save,
          ),
        ),
        if (_failed) Text(l.preferenceSaveFailed),
      ],
    );
  }
}
