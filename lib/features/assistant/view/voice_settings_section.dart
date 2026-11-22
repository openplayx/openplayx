import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../assistant/voice/voice_settings.dart';
import '../../../assistant/voice/voice_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../ui/components/forms/form_actions.dart';
import '../../../ui/components/forms/secret_input.dart';
import '../../../ui/components/forms/settings_text_input.dart';
import '../../../ui/components/settings/settings_section.dart';

class VoiceSettingsSection extends StatefulWidget {
  const VoiceSettingsSection({
    super.key,
    required this.settings,
    this.testConnection,
  });
  final VoiceSettings settings;
  final Future<void> Function(VoiceConfig config, String key)? testConnection;
  @override
  State<VoiceSettingsSection> createState() => _VoiceSettingsSectionState();
}

class _VoiceSettingsSectionState extends State<VoiceSettingsSection> {
  final _endpoint = TextEditingController();
  final _model = TextEditingController();
  final _key = SecretController();
  bool _busy = false;
  bool _testing = false;
  final _probe = OpenAiVoiceTranscriber();
  late bool _cloudTab;
  late bool _activeCloud;
  String? _result;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final config = widget.settings.load();
    _cloudTab = _activeCloud = config.usePlatform;
    _endpoint.text = config.endpoint;
    _model.text = config.model;
    _key.loadStored(widget.settings.key);
    for (final field in [_endpoint, _model, _key]) {
      field.addListener(_edited);
    }
  }

  void _edited() {
    if (mounted && _result != null) setState(() => _result = null);
  }

  VoiceConfig get _draft => VoiceConfig(
    usePlatform: _cloudTab,
    endpoint: VoiceConfig.normalizeEndpoint(_endpoint.text),
    model: _model.text.trim(),
  );

  Future<void> _test() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _testing = true;
      _result = null;
    });
    try {
      final config = _draft..validate();
      final key = _cloudTab
          ? 'platform'
          : _key.text.trim().isNotEmpty
          ? _key.text.trim()
          : await widget.settings.key();
      if (!config.usePlatform && key.isEmpty) {
        throw const VoiceFailure('missingKey');
      }
      await (widget.testConnection ?? _probe.testConnection)(config, key);
      if (!mounted) return;
      _result = l.voiceConnectionOk;
      _failed = false;
    } on FormatException {
      if (!mounted) return;
      _result = l.voiceSettingsError;
      _failed = true;
    } catch (e) {
      if (!mounted) return;
      _result = switch (e) {
        VoiceFailure(code: 'missingKey') => l.aiKeyRequired,
        VoiceFailure(code: 'authentication') => l.aiAuthenticationFailed,
        VoiceFailure(code: 'rateLimited') => l.aiRateLimited,
        VoiceFailure(code: 'timeout') => l.voiceConnectionTimeout,
        _ => l.voiceTranscriptionError,
      };
      _failed = true;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _testing = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    final l = AppLocalizations.of(context);
    try {
      await widget.settings.save(_draft, _key.text);
      if (!mounted) return;
      _key.markSaved();
      _activeCloud = _cloudTab;
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
    _probe.cancel();
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
        ShadTabs<bool>(
          key: const ValueKey('voice-mode-tabs'),
          value: _cloudTab,
          onChanged: (cloud) {
            if (_busy) return;
            setState(() {
              _cloudTab = cloud;
              _result = null;
            });
          },
          tabs: [
            for (final cloud in [true, false])
              ShadTab(
                enabled: !_busy,
                key: ValueKey(cloud ? 'voice-tab-cloud' : 'voice-tab-local'),
                value: cloud,
                trailing: _activeCloud == cloud
                    ? const Icon(Icons.check, size: 14)
                    : null,
                child: Text(cloud ? l.remoteTabCloud : l.remoteTabLocal),
              ),
          ],
        ),
        SettingsSection(
          title: l.voiceSettings,
          footer: _cloudTab ? l.voiceCloudHint : null,
          children: [
            SettingsRow(
              title: _activeCloud == _cloudTab
                  ? l.remoteModeActive
                  : l.remoteModeInactive,
              control: Icon(
                _activeCloud == _cloudTab
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 20,
              ),
            ),
          ],
        ),
        if (!_cloudTab)
          SettingsSection(
            footer: l.voiceSettingsHint,
            children: [
              SettingsRow(
                title: l.aiEndpoint,
                stacked: true,
                control: SettingsTextInput(
                  key: const ValueKey('voice-settings-endpoint'),
                  controller: _endpoint,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                ),
              ),
              SettingsRow(
                title: l.aiModel,
                stacked: true,
                control: SettingsTextInput(
                  key: const ValueKey('voice-settings-model'),
                  controller: _model,
                  enabled: !_busy,
                ),
              ),
              SettingsRow(
                title: l.aiApiKey,
                stacked: true,
                control: SecretInput(
                  key: const ValueKey('voice-settings-key'),
                  controller: _key,
                  enabled: !_busy,
                ),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            l.voiceConnectionTestHint,
            style: ShadTheme.of(context).textTheme.muted,
          ),
        ),
        FormActions(
          status: _busy
              ? FormStatus.busy(_testing ? l.aiCheckingConnection : l.saving)
              : _result == null
              ? FormStatus.idle
              : FormStatus.result(_result!, failed: _failed),
          [
            FormAction(
              l.aiTestConnection,
              _busy ? null : _test,
              key: const ValueKey('voice-settings-test'),
            ),
            FormAction.primary(
              _activeCloud == _cloudTab
                  ? l.save
                  : _cloudTab
                  ? l.remoteEnableCloud
                  : l.remoteEnableLocal,
              _busy ? null : _save,
              key: const ValueKey('voice-settings-save'),
            ),
          ],
        ),
      ],
    );
  }
}
