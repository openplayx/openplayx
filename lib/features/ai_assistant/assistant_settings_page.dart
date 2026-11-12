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
import '../../ui/tokens/app_spacing.dart';
import 'widgets/ai_failure_message.dart';

/// Model settings: API domain, model name and key, plus one connection test.
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
  final _key = TextEditingController();
  late bool _tools = _saved.toolsSupported;
  bool _busy = false;
  String? _message;
  bool _ok = false;
  @override
  void dispose() {
    _endpoint.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  // Accept a pasted full URL such as .../v1/chat/completions or a trailing /.
  static String _normalize(String endpoint) {
    var value = endpoint.trim();
    if (value.endsWith('/chat/completions')) {
      value = value.substring(0, value.length - '/chat/completions'.length);
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  /// Runs one probe; returns true when the model answered as asked.
  Future<bool> _probe(LangChainModel model, {required bool tools}) async {
    final request = ModelInferenceRequest(
      [
        ModelMessage(
          'user',
          tools
              ? 'Call connection_probe with value ok. This is a protocol test.'
              : 'Reply with OK.',
        ),
      ],
      tools: tools
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
    var text = false, tool = false, complete = false;
    await for (final event
        in model.infer(request).timeout(const Duration(seconds: 30))) {
      if (event is ModelTextDelta && event.text.trim().isNotEmpty) text = true;
      if (event is ModelCompleted) complete = true;
      if (event is ModelToolDelta) {
        final args = jsonDecode(event.call.arguments);
        tool =
            event.call.name == 'connection_probe' &&
            args is Map &&
            args['value'] == 'ok';
      }
    }
    return complete && (tools ? tool : text);
  }

  AssistantConfig get _draft => AssistantConfig(
    endpoint: _normalize(_endpoint.text),
    model: _model.text.trim(),
    maxTokens: _saved.maxTokens,
    cloudAllowed: true,
    textVerified: true,
    streamVerified: true,
    toolsSupported: _tools,
  );

  void _show(String message, {bool ok = false}) {
    if (mounted) {
      setState(() {
        _message = message;
        _ok = ok;
      });
    }
  }

  Future<void> _run(Future<void> Function(AppLocalizations l) task) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await task(l);
    } on FormatException {
      _show(l.aiInvalidSettings);
    } on ModelFailure catch (failure) {
      _show(
        failure.code == 'missingKey'
            ? l.aiKeyRequired
            : aiFailureMessage(failure.code, l),
      );
    } on TimeoutException {
      _show(l.aiTimeout);
    } catch (_) {
      _show(l.aiSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // One button: a plain reply must work; tool calls are optional (without
  // them the assistant only chats).
  Future<void> _test() => _run((l) async {
    final draft = _draft..validate();
    final secret = _key.text.trim().isNotEmpty
        ? _key.text.trim()
        : await widget.store.key(_saved);
    if (secret.isEmpty) throw const ModelFailure('missingKey');
    final model = LangChainModel(
      apiKey: secret,
      endpoint: draft.endpoint,
      model: draft.model,
      maxTokens: draft.maxTokens,
    );
    if (!await _probe(model, tools: false)) {
      throw const ModelFailure('protocolMismatch');
    }
    var tools = false;
    try {
      tools = await _probe(model, tools: true);
    } catch (_) {}
    _tools = tools;
    _show(tools ? l.aiConnectionOk : l.aiConnectionOkNoTools, ok: true);
  });

  Future<void> _save() => _run((l) async {
    final draft = _draft..validate();
    if (_key.text.trim().isEmpty && _saved.credentialRef == null) {
      throw const ModelFailure('missingKey');
    }
    await widget.store.saveConfig(draft, _key.text.trim());
    _key.clear();
    if (mounted) Navigator.of(context).pop();
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
        // A changed provider or model must be tested again for tools.
        onChanged: (_) => setState(() {
          _message = null;
          _tools = false;
        }),
        placeholder: placeholder == null ? null : Text(placeholder),
      ),
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
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                children: [
                  const ShadProgress(),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l.aiCheckingConnection,
                    style: ShadTheme.of(context).textTheme.muted,
                  ),
                ],
              ),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: _ok
                  ? ShadAlert(title: Text(_message!))
                  : ShadAlert.destructive(title: Text(_message!)),
            ),
          SettingsSection(
            footer: l.aiProviderDescription,
            children: [
              field(
                l.aiEndpoint,
                _endpoint,
                keyboardType: TextInputType.url,
                placeholder: 'https://api.deepseek.com',
              ),
              field(l.aiModel, _model, placeholder: 'deepseek-chat'),
              field(
                l.aiApiKey,
                _key,
                secret: true,
                placeholder: _saved.credentialRef == null
                    ? l.aiKeyRequired
                    : l.aiKeySaved,
              ),
            ],
          ),
          SettingsSection(
            children: [
              SettingsRow(
                key: const ValueKey('ai-test'),
                title: l.aiTestConnection,
                accent: true,
                onTap: _busy ? null : _test,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
