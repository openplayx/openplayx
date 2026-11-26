import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../capabilities/speech/asr_backend_config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/forms/form_actions.dart';
import '../../ui/components/forms/secret_input.dart';
import '../../ui/components/forms/settings_text_input.dart';
import '../../ui/components/settings/settings_section.dart';

class AsrHttpServiceSettingsPage extends StatefulWidget {
  const AsrHttpServiceSettingsPage({
    super.key,
    required this.registry,
    this.existing,
  });

  final AsrBackendRegistry registry;
  final AsrBackendConfig? existing;

  @override
  State<AsrHttpServiceSettingsPage> createState() =>
      _AsrHttpServiceSettingsPageState();
}

class _AsrHttpServiceSettingsPageState
    extends State<AsrHttpServiceSettingsPage> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _url = TextEditingController(text: widget.existing?.url ?? '');
  late final _model = DefaultTextController(
    text: widget.existing?.modelId,
    defaultValue: 'whisper-large-v3',
  );
  late final _language = DefaultTextController(
    text: widget.existing?.language,
    defaultValue: 'auto',
  );
  final _token = SecretController();
  late bool _insecure = widget.existing?.allowInsecureHttp ?? false;
  late String _protocol = widget.existing?.protocol ?? 'openai';
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _token.loadStored(() => widget.registry.credential(existing));
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _url, _model, _language, _token]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final l = AppLocalizations.of(context);
    final existing = widget.existing;
    try {
      final saved = widget.registry.save(
        AsrBackendConfig(
          id: existing?.id ?? AsrBackendRegistry.newId(),
          kind: 'http',
          protocol: _protocol,
          name: _name.text,
          url: _url.text.trim(),
          modelId: _model.resolved,
          language: _language.resolved,
          allowInsecureHttp: _insecure,
          uploadConsentAt: existing?.uploadConsentAt,
        ),
      );
      widget.registry.selectDefault(saved.id);
      if (_token.edited.isNotEmpty) {
        widget.registry.setToken(saved.id, _token.edited);
      }
      Navigator.of(context).pop();
    } on FormatException catch (e) {
      setState(
        () => _error = e.message == 'url'
            ? l.asrServiceUrlInvalid
            : l.asrServiceInvalid,
      );
    }
  }

  Future<void> _remove() async {
    await widget.registry.remove(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _field(String title, Widget input) =>
      SettingsRow(title: title, stacked: true, control: input);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppPage(
      pageContext: const PageContextData(pageType: 'asr_service_settings'),
      title: Text(widget.existing == null ? l.asrAddService : l.asrEditService),
      body: SettingsListView(
        children: [
          SettingsSection(
            footer: l.asrServicePrivacy,
            children: [
              SettingsRow(
                title: l.asrProtocol,
                control: ShadSelect<String>(
                  initialValue: _protocol,
                  options: const [
                    ShadOption(
                      value: 'openai',
                      child: Text('OpenAI-compatible'),
                    ),
                    ShadOption(
                      value: 'openplayx',
                      child: Text('OpenPlayX ASR'),
                    ),
                  ],
                  selectedOptionBuilder: (_, value) => Text(
                    value == 'openai' ? 'OpenAI-compatible' : 'OpenPlayX ASR',
                  ),
                  onChanged: (value) {
                    if (value != null) setState(() => _protocol = value);
                  },
                ),
              ),
              _field(l.asrServiceName, SettingsTextInput(controller: _name)),
              _field(
                l.asrServiceUrl,
                SettingsTextInput(
                  key: const ValueKey('asr-service-url'),
                  controller: _url,
                  keyboardType: TextInputType.url,
                  example: 'https://asr.example.com',
                ),
              ),
              _field(
                l.asrServiceToken,
                SecretInput(
                  controller: _token,
                  placeholder: widget.existing == null
                      ? null
                      : l.metadataTokenStatusSaved,
                ),
              ),
              _field(l.asrModel, SettingsTextInput(controller: _model)),
              _field(l.asrLanguage, SettingsTextInput(controller: _language)),
              SettingsRow(
                title: l.asrAllowHttp,
                description: l.asrAllowHttpHint,
                control: ShadSwitch(
                  value: _insecure,
                  onChanged: (value) => setState(() => _insecure = value),
                ),
              ),
            ],
          ),
          FormActions([
            if (widget.existing != null)
              FormAction.destructive(l.asrRemoveService, _remove),
            FormAction.primary(
              l.save,
              _save,
              key: const ValueKey('asr-service-save'),
            ),
          ], status: _error == null ? null : FormStatus.error(_error!)),
        ],
      ),
    );
  }
}
