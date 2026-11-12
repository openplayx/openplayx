import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/models/text_model.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../plugins/model_langchain/langchain_model.dart';
import '../../services/conversations/assistant_store.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/settings/settings_section.dart';
import '../../ui/icons/app_icons.dart';
import '../../ui/tokens/app_spacing.dart';

class AssistantSettingsPage extends StatefulWidget {
  const AssistantSettingsPage({super.key, required this.store});
  final AssistantStore store;
  @override
  State<AssistantSettingsPage> createState() => _AssistantSettingsPageState();
}

class _AssistantSettingsPageState extends State<AssistantSettingsPage> {
  late final _saved = widget.store.loadConfig();
  late final _endpoint = TextEditingController(text: _saved.endpoint);
  late final _model = TextEditingController(text: _saved.model);
  late final _tokens = TextEditingController(text: '${_saved.maxTokens}');
  final _key = TextEditingController();
  late bool _cloud = _saved.cloudAllowed;
  late bool _text = _saved.textVerified;
  late bool _stream = _saved.streamVerified;
  late bool _tools = _saved.toolsSupported;
  bool _busy = false;
  String? _message;
  @override
  void dispose() {
    _endpoint.dispose();
    _model.dispose();
    _tokens.dispose();
    _key.dispose();
    super.dispose();
  }

  AssistantConfig get _draft => AssistantConfig(
    endpoint: _endpoint.text.trim(),
    model: _model.text.trim(),
    maxTokens: int.tryParse(_tokens.text) ?? 0,
    cloudAllowed: _cloud,
    toolsSupported: _tools,
    textVerified: _text,
    streamVerified: _stream,
  );
  void _changed(String _) => setState(() {
    _text = false;
    _stream = false;
    _tools = false;
    _cloud = false;
    _message = null;
  });
  Future<void> _test(String kind) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final draft = _draft;
      draft.validate();
      final secret = _key.text.isNotEmpty
          ? _key.text
          : await widget.store.key(_saved);
      if (secret.isEmpty) throw const ModelFailure('missingKey');
      final model = LangChainModel(
        apiKey: secret,
        endpoint: draft.endpoint,
        model: draft.model,
        maxTokens: draft.maxTokens,
        streaming: kind != 'text',
      );
      final request = ModelInferenceRequest(
        [
          ModelMessage(
            'user',
            kind == 'tools'
                ? 'Call connection_probe with value ok. This is a protocol test.'
                : 'Reply with OK.',
          ),
        ],
        tools: kind == 'tools'
            ? [
                const ModelTool(
                  'connection_probe',
                  'Protocol test with no business effects.',
                  {
                    'type': 'object',
                    'properties': {
                      'value': {
                        'type': 'string',
                        'enum': ['ok'],
                      },
                    },
                    'required': ['value'],
                    'additionalProperties': false,
                  },
                ),
              ]
            : [],
      );
      var text = false;
      var tool = false;
      var complete = false;
      await for (final event
          in model.infer(request).timeout(const Duration(seconds: 30))) {
        if (event is ModelTextDelta && event.text.trim().isNotEmpty) {
          text = true;
        }
        if (event is ModelCompleted) {
          complete = true;
        }
        if (event is ModelToolDelta) {
          final args = jsonDecode(event.call.arguments);
          tool =
              event.call.id.isNotEmpty &&
              event.call.name == 'connection_probe' &&
              args is Map &&
              args.length == 1 &&
              args['value'] == 'ok';
        }
      }
      if (!complete || (kind == 'tools' ? !tool : !text)) {
        throw const ModelFailure('protocolUnsupported');
      }
      if (!mounted) return;
      setState(() {
        if (kind == 'text') _text = true;
        if (kind == 'stream') _stream = true;
        if (kind == 'tools') _tools = true;
        _message = l.aiTestPassed;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          if (kind == 'text') _text = false;
          if (kind == 'stream') _stream = false;
          if (kind == 'tools') _tools = false;
          _message = l.aiTestFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.store.saveConfig(_draft, _key.text);
      _key.clear();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _message = l.aiSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = ShadTheme.of(context).colorScheme;
    Widget field(
      String label,
      TextEditingController controller, {
      bool secret = false,
      TextInputType? keyboardType,
      String? placeholder,
    }) => SettingsRow(
      title: label,
      stacked: true,
      control: ShadInput(
        controller: controller,
        enabled: !_busy,
        obscureText: secret,
        keyboardType: keyboardType,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: _changed,
        placeholder: placeholder == null ? null : Text(placeholder),
      ),
    );
    Widget test(String kind, String label, bool passed) => SettingsRow(
      title: label,
      accent: true,
      onTap: _busy ? null : () => _test(kind),
      control: passed
          ? Icon(AppIcons.success, size: 20, color: colors.primary)
          : null,
    );
    return AppPage(
      title: Text(l.aiModelSettings),
      trailing: [
        ShadButton.ghost(
          key: const ValueKey('ai-save'),
          onPressed: _busy ? null : _save,
          child: Text(l.save),
        ),
      ],
      body: SettingsListView(
        children: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.lg),
              child: ShadProgress(),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: ShadAlert(title: Text(_message!)),
            ),
          SettingsSection(
            footer: l.aiProviderDescription,
            children: [
              field(l.aiEndpoint, _endpoint, keyboardType: TextInputType.url),
              field(l.aiModel, _model),
              field(
                l.aiApiKey,
                _key,
                secret: true,
                placeholder: _saved.credentialRef == null
                    ? l.aiKeyRequired
                    : l.aiKeySaved,
              ),
              field(
                l.aiOutputLimit,
                _tokens,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          SettingsSection(
            children: [
              SettingsRow(
                title: l.aiCloudConsentTitle,
                description: l.aiCloudConsent,
                control: ShadSwitch(
                  value: _cloud,
                  enabled: !_busy,
                  onChanged: (value) => setState(() => _cloud = value),
                ),
              ),
            ],
          ),
          SettingsSection(
            footer: _tools ? l.aiToolsVerified : l.aiTextOnly,
            children: [
              test('text', l.aiTestText, _text),
              test('stream', l.aiTestStream, _stream),
              test('tools', l.aiTestTools, _tools),
            ],
          ),
        ],
      ),
    );
  }
}
