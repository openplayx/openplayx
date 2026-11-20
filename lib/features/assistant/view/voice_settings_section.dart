import 'package:flutter/material.dart';

import '../../../assistant/voice/voice_settings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../ui/components/forms/form_actions.dart';
import '../../../ui/components/forms/secret_input.dart';
import '../../../ui/components/forms/settings_text_input.dart';
import '../../../ui/components/settings/settings_section.dart';

class VoiceSettingsSection extends StatefulWidget {
  const VoiceSettingsSection({super.key, required this.settings});
  final VoiceSettings settings;
  @override
  State<VoiceSettingsSection> createState() => _VoiceSettingsSectionState();
}

class _VoiceSettingsSectionState extends State<VoiceSettingsSection> {
  final _endpoint = TextEditingController();
  final _model = TextEditingController();
  final _key = SecretController();
  bool _busy = false;
  String? _result;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final config = widget.settings.load();
    _endpoint.text = config.endpoint;
    _model.text = config.model;
    _key.loadStored(widget.settings.key);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    final l = AppLocalizations.of(context);
    try {
      await widget.settings.save(
        VoiceConfig(
          endpoint: VoiceConfig.normalizeEndpoint(_endpoint.text),
          model: _model.text.trim(),
        ),
        _key.text,
      );
      if (!mounted) return;
      _key.markSaved();
      _result = l.aiSettingsSaved;
      _failed = false;
    } catch (_) {
      if (!mounted) return;
      _result = l.voiceSettingsError;
      _failed = true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: l.voiceSettings,
          footer: l.voiceSettingsHint,
          children: [
            SettingsRow(
              title: l.aiEndpoint,
              stacked: true,
              control: SettingsTextInput(
                controller: _endpoint,
                enabled: !_busy,
                keyboardType: TextInputType.url,
              ),
            ),
            SettingsRow(
              title: l.aiModel,
              stacked: true,
              control: SettingsTextInput(controller: _model, enabled: !_busy),
            ),
            SettingsRow(
              title: l.aiApiKey,
              stacked: true,
              control: SecretInput(controller: _key, enabled: !_busy),
            ),
          ],
        ),
        FormActions(
          status: _busy
              ? FormStatus.busy(l.saving)
              : _result == null
              ? FormStatus.idle
              : FormStatus.result(_result!, failed: _failed),
          [
            FormAction.primary(
              l.save,
              _busy ? null : _save,
              key: const ValueKey('voice-settings-save'),
            ),
          ],
        ),
      ],
    );
  }
}
