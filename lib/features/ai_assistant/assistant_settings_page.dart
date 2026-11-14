import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/models/text_model.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../plugins/model_langchain/langchain_model.dart';
import '../../services/conversations/assistant_store.dart';
import '../../ui/components/forms/form_actions.dart';
import '../../ui/components/forms/secret_input.dart';
import '../../ui/components/forms/settings_text_input.dart';
import '../../ui/components/settings/settings_section.dart';
import 'widgets/ai_failure_message.dart';
import '../../ui/components/feedback/app_feedback.dart';

/// Model settings form: API domain, model name and key, one connection test
/// and save. Embedded in the AI page's 模型 tab (it is not a page itself).
class AssistantModelSettings extends StatefulWidget {
  const AssistantModelSettings({super.key, required this.store, this.onSaved});
  final AssistantStore store;

  /// Called after a successful save (e.g. to refresh plugin status).
  final Future<void> Function()? onSaved;
  @override
  State<AssistantModelSettings> createState() => _AssistantModelSettingsState();
}

class _AssistantModelSettingsState extends State<AssistantModelSettings> {
  late var _saved = widget.store.loadConfig();
  // Before the first save the fields stay blank with example hints: the
  // provider and model are the user's choice, not a silent default.
  late final _endpoint = TextEditingController(
    text: _saved.configured ? _saved.endpoint : '',
  );
  late final _model = TextEditingController(
    text: _saved.configured ? _saved.model : '',
  );
  final _key = SecretController();
  late bool _tools = _saved.toolsSupported;

  /// What is running (shown in the action bar), or null when idle.
  String? _busyLabel;
  bool get _busy => _busyLabel != null;
  String? _message;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    if (_saved.configured) {
      _key.loadStored(() => widget.store.key(_saved));
    }
  }

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

  Future<void> _run(
    String busyLabel,
    Future<void> Function(AppLocalizations l) task,
  ) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busyLabel = busyLabel;
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
      if (mounted) setState(() => _busyLabel = null);
    }
  }

  // One button: a plain reply must work; tool calls are optional (without
  // them the assistant only chats).
  Future<void> _test() =>
      _run(AppLocalizations.of(context).aiCheckingConnection, (l) async {
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

  Future<void> _save() => _run(AppLocalizations.of(context).saving, (l) async {
    final draft = _draft..validate();
    if (_key.text.trim().isEmpty && !_saved.configured) {
      throw const ModelFailure('missingKey');
    }
    await widget.store.saveConfig(draft, _key.edited);
    _key.markSaved();
    _saved = widget.store.loadConfig();
    await widget.onSaved?.call();
    // A plain "saved" is a toast; the action bar keeps test results/errors.
    if (mounted) {
      showAppToast(context, l.aiSettingsSaved, kind: FeedbackKind.success);
    }
  });

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
      void changed(String _) => setState(() {
        _message = null;
        _tools = false;
      });
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
          footer: l.aiProviderDescription,
          children: [
            field(
              l.aiEndpoint,
              _endpoint,
              keyboardType: TextInputType.url,
              example: AssistantConfig.exampleEndpoint,
            ),
            field(l.aiModel, _model, example: AssistantConfig.exampleModel),
            field(
              l.aiApiKey,
              _key,
              example: _saved.configured ? l.aiKeySaved : 'sk-…',
            ),
          ],
        ),
        FormActions(
          status: _busy
              ? FormStatus.busy(_busyLabel!)
              : _message == null
              ? FormStatus.idle
              : FormStatus.result(_message!, failed: !_ok),
          [
            FormAction(
              l.aiTestConnection,
              _busy ? null : _test,
              key: const ValueKey('ai-test'),
            ),
            FormAction.primary(
              l.save,
              _busy ? null : _save,
              key: const ValueKey('ai-save'),
            ),
          ],
        ),
      ],
    );
  }
}
