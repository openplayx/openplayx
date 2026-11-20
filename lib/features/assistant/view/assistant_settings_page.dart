import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../assistant/voice/voice_settings.dart';
import 'voice_settings_section.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../assistant/conversation/assistant_store.dart';
import '../../../ui/components/forms/form_actions.dart';
import '../../../ui/components/forms/secret_input.dart';
import '../../../ui/components/forms/settings_text_input.dart';
import '../../../ui/components/settings/settings_section.dart';
import '../controller/model_config_controller.dart';
import 'widgets/ai_failure_message.dart';
import '../../../ui/components/feedback/app_feedback.dart';

/// Platform service by default, with an optional custom provider form.
/// Embedded in the AI page's model settings.
class AssistantModelSettings extends StatefulWidget {
  const AssistantModelSettings({super.key, required this.store, this.onSaved});
  final AssistantStore store;

  /// Called after a successful save (e.g. to refresh plugin status).
  final Future<void> Function()? onSaved;
  @override
  State<AssistantModelSettings> createState() => _AssistantModelSettingsState();
}

class _AssistantModelSettingsState extends State<AssistantModelSettings> {
  late final _c = ModelConfigController(
    store: widget.store,
    onSaved: widget.onSaved,
  )..addListener(_changed);

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _busy => _c.busy;

  String _message(ModelConfigResult r, AppLocalizations l) =>
      switch (r.outcome) {
        ModelConfigOutcome.connectionOk => l.aiConnectionOk,
        ModelConfigOutcome.connectionOkNoTools => l.aiConnectionOkNoTools,
        ModelConfigOutcome.invalidSettings => l.aiInvalidSettings,
        ModelConfigOutcome.keyRequired => l.aiKeyRequired,
        ModelConfigOutcome.modelFailure => aiFailureMessage(r.failureCode!, l),
        ModelConfigOutcome.timeout => l.aiTimeout,
        ModelConfigOutcome.saveFailed => l.aiSaveFailed,
      };

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    // A plain "saved" is a toast; the action bar keeps test results/errors.
    if (await _c.save() && mounted) {
      showAppToast(context, l.aiSettingsSaved, kind: FeedbackKind.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget field(
      String label,
      TextEditingController controller, {
      TextInputType? keyboardType,
      String? example,
    }) {
      // A changed provider or model must be tested again for tools.
      void changed(String _) => _c.edited();
      return SettingsRow(
        title: label,
        stacked: true,
        control: controller is SecretController
            ? SecretInput(
                controller: controller,
                enabled: !_busy,
                onChanged: changed,
                placeholder: example,
              )
            : SettingsTextInput(
                controller: controller,
                enabled: !_busy,
                keyboardType: keyboardType,
                onChanged: changed,
                example: example,
              ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          footer: _c.usePlatform ? l.aiPlatformPrivacy : l.aiCustomServiceHint,
          children: [
            SettingsRow(
              title: l.aiUsePlatform,
              description: l.aiUsePlatformHint,
              control: ShadCheckbox(
                key: const ValueKey('ai-use-platform'),
                value: _c.usePlatform,
                enabled: !_busy,
                onChanged: _c.setUsePlatform,
              ),
              onTap: _busy ? null : () => _c.setUsePlatform(!_c.usePlatform),
            ),
          ],
        ),
        if (!_c.usePlatform)
          SettingsSection(
            key: const ValueKey('ai-model-fields'),
            title: l.aiCustomService,
            footer: l.aiProviderDescription,
            children: [
              field(
                l.aiEndpoint,
                _c.endpoint,
                keyboardType: TextInputType.url,
                example: AssistantConfig.exampleEndpoint,
              ),
              field(l.aiModel, _c.model, example: AssistantConfig.exampleModel),
              field(
                l.aiApiKey,
                _c.key,
                example: _c.key.hasStored ? l.aiKeySaved : 'sk-…',
              ),
            ],
          ),
        FormActions(
          status: switch (_c.task) {
            ModelConfigTask.testing => FormStatus.busy(l.aiCheckingConnection),
            ModelConfigTask.saving => FormStatus.busy(l.saving),
            null => switch (_c.result) {
              null => FormStatus.idle,
              final r => FormStatus.result(_message(r, l), failed: !r.ok),
            },
          },
          [
            FormAction(
              l.aiTestConnection,
              _busy ? null : _c.test,
              key: const ValueKey('ai-test'),
            ),
            FormAction.primary(
              l.save,
              _busy ? null : _save,
              key: const ValueKey('ai-save'),
            ),
          ],
        ),
        VoiceSettingsSection(
          settings: VoiceSettings(widget.store.configuration),
        ),
      ],
    );
  }
}
