import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../assistant/conversation/assistant_store.dart';
import '../../../assistant/model/langchain_model.dart';
import '../../../assistant/model/model_probe.dart';
import '../../../core/models/text_model.dart';
import '../../../ui/components/forms/secret_input.dart';

/// What the model settings are doing right now.
enum ModelConfigTask { testing, saving }

/// Outcome of a test or save, shown in the action bar.
enum ModelConfigOutcome {
  connectionOk,
  connectionOkNoTools,
  invalidSettings,
  keyRequired,

  /// The model failed with [ModelConfigResult.failureCode].
  modelFailure,
  timeout,
  saveFailed,
}

@immutable
class ModelConfigResult {
  const ModelConfigResult(this.outcome, [this.failureCode]);
  final ModelConfigOutcome outcome;
  final String? failureCode;
  bool get ok =>
      outcome == ModelConfigOutcome.connectionOk ||
      outcome == ModelConfigOutcome.connectionOkNoTools;
}

/// The assistant's model settings: API domain, model and key, one
/// connection test and save.
class ModelConfigController extends ChangeNotifier {
  ModelConfigController({required this.store, this.onSaved}) {
    _saved = store.loadConfig();
    // Before the first save the fields stay blank with example hints: the
    // provider and model are the user's choice, not a silent default.
    endpoint.text = _saved.configured ? _saved.endpoint : '';
    model.text = _saved.configured ? _saved.model : '';
    _tools = _saved.toolsSupported;
    if (_saved.configured) key.loadStored(() => store.key(_saved));
  }

  final AssistantStore store;

  /// Called after a successful save (e.g. to refresh plugin status).
  final Future<void> Function()? onSaved;

  final endpoint = TextEditingController();
  final model = TextEditingController();
  final key = SecretController();

  late AssistantConfig _saved;
  bool get configured => _saved.configured;
  late bool _tools;
  ModelConfigTask? _task;
  ModelConfigTask? get task => _task;
  bool get busy => _task != null;
  ModelConfigResult? _result;
  ModelConfigResult? get result => _result;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// A changed provider or model must be tested again for tools.
  void edited() {
    _result = null;
    _tools = false;
    _notify();
  }

  // Accept a pasted full URL such as .../v1/chat/completions or a trailing /.
  static String normalizeEndpoint(String endpoint) {
    var value = endpoint.trim();
    if (value.endsWith('/chat/completions')) {
      value = value.substring(0, value.length - '/chat/completions'.length);
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  AssistantConfig get _draft => AssistantConfig(
    endpoint: normalizeEndpoint(endpoint.text),
    model: model.text.trim(),
    maxTokens: _saved.maxTokens,
    cloudAllowed: true,
    textVerified: true,
    streamVerified: true,
    toolsSupported: _tools,
  );

  /// Runs [action]; failures become the shown result. True when it
  /// completed.
  Future<bool> _run(
    ModelConfigTask task,
    Future<void> Function() action,
  ) async {
    _task = task;
    _result = null;
    _notify();
    try {
      await action();
      return true;
    } on FormatException {
      _result = const ModelConfigResult(ModelConfigOutcome.invalidSettings);
    } on ModelFailure catch (failure) {
      _result = failure.code == 'missingKey'
          ? const ModelConfigResult(ModelConfigOutcome.keyRequired)
          : ModelConfigResult(ModelConfigOutcome.modelFailure, failure.code);
    } on TimeoutException {
      _result = const ModelConfigResult(ModelConfigOutcome.timeout);
    } catch (_) {
      _result = const ModelConfigResult(ModelConfigOutcome.saveFailed);
    } finally {
      _task = null;
      _notify();
    }
    return false;
  }

  /// A plain reply must work; tool calls are optional.
  Future<void> test() => _run(ModelConfigTask.testing, () async {
    final draft = _draft..validate();
    final secret = key.text.trim().isNotEmpty
        ? key.text.trim()
        : await store.key(_saved);
    if (secret.isEmpty) throw const ModelFailure('missingKey');
    final candidate = LangChainModel(
      apiKey: secret,
      endpoint: draft.endpoint,
      model: draft.model,
      maxTokens: draft.maxTokens,
    );
    if (!await ModelProbe.replies(candidate)) {
      throw const ModelFailure('protocolMismatch');
    }
    _tools = await ModelProbe.callsTools(candidate);
    _result = ModelConfigResult(
      _tools
          ? ModelConfigOutcome.connectionOk
          : ModelConfigOutcome.connectionOkNoTools,
    );
  });

  /// Saves the settings; true when saved (the view confirms it).
  Future<bool> save() => _run(ModelConfigTask.saving, () async {
    final draft = _draft..validate();
    if (key.text.trim().isEmpty && !_saved.configured) {
      throw const ModelFailure('missingKey');
    }
    await store.saveConfig(draft, key.edited);
    key.markSaved();
    _saved = store.loadConfig();
    await onSaved?.call();
  });

  @override
  void dispose() {
    _disposed = true;
    endpoint.dispose();
    model.dispose();
    key.dispose();
    super.dispose();
  }
}
