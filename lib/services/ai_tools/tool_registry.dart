import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/models/text_model.dart';
import 'json_schema_lite.dart';

/// Host cancellation scope follows asynchronous business work across awaits.
/// A timed-out resolver cannot start playback later, even in a new user turn.
class ToolExecution {
  static final Object _key = Object();
  static final Object _progressKey = Object();
  static bool get active =>
      (Zone.current[_key] as bool Function()?)?.call() ?? true;
  static Future<T> run<T>(
    Future<T> Function() action,
    bool Function() active, {
    void Function(Map<String, dynamic>)? progress,
  }) => runZoned(action, zoneValues: {_key: active, _progressKey: ?progress});

  /// Live progress of the running tool (e.g. a task it waits on), shown on
  /// its card. Display only: never sent to the model.
  static void report(Map<String, dynamic> progress) =>
      (Zone.current[_progressKey] as void Function(Map<String, dynamic>)?)
          ?.call(progress);
}

class ToolFailure implements Exception {
  const ToolFailure(this.code);
  final String code;
}

/// Deliberately small schema vocabulary, shared by declarations and validation.
/// Unsupported schema keywords are rejected at registration, never ignored.
class ToolField {
  const ToolField(
    this.type, {
    this.required = false,
    this.minimum,
    this.maximum,
    this.maxLength = 200,
    this.values,
  });
  final String type;
  final bool required;
  final num? minimum;
  final num? maximum;
  final int maxLength;
  final List<String>? values;
  Map<String, dynamic> get schema => {
    'type': type,
    if (type == 'string') ...{'minLength': 1, 'maxLength': maxLength},
    if (minimum != null) 'minimum': minimum,
    if (maximum != null) 'maximum': maximum,
    if (values != null) 'enum': values,
  };
  bool valid(Object? value) {
    if (type == 'string') {
      return value is String &&
          value.isNotEmpty &&
          value.length <= maxLength &&
          (values == null || values!.contains(value));
    }
    if (type == 'boolean') return value is bool;
    if (type == 'integer' && value is! int) return false;
    if (type != 'integer' && type != 'number') return false;
    return value is num &&
        value.isFinite &&
        (minimum == null || value >= minimum!) &&
        (maximum == null || value <= maximum!);
  }
}

class RegisteredTool {
  RegisteredTool(
    this.name,
    this.description,
    this.fields,
    this.execute, {
    this.available,
    this.confirmation = false,
    this.readOnly = true,
    this.timeout,
    this.schema,
  }) {
    if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(name) ||
        fields.values.any(
          (f) => !['string', 'integer', 'number', 'boolean'].contains(f.type),
        ) ||
        (schema != null &&
            (fields.isNotEmpty ||
                schema!['type'] != 'object' ||
                JsonSchemaLite.unsupported(schema) != null))) {
      throw ArgumentError('Unsupported tool definition');
    }
  }
  final String name;
  final String description;
  final Map<String, ToolField> fields;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) execute;
  final bool Function()? available;
  final bool confirmation;
  final bool readOnly;

  /// Overrides the gateway timeout for tools that wait on background work
  /// or upload; the work itself must stay cancellable via [ToolExecution].
  final Duration? timeout;

  /// A full input JSON Schema (external MCP tools) instead of [fields];
  /// limited to [JsonSchemaLite] and validated before every execution.
  final Map<String, dynamic>? schema;
  ModelTool get model => ModelTool(
    name,
    description,
    schema ??
        {
          'type': 'object',
          'properties': fields.map((k, v) => MapEntry(k, v.schema)),
          'required': fields.entries
              .where((e) => e.value.required)
              .map((e) => e.key)
              .toList(),
          'additionalProperties': false,
        },
  );
  Map<String, dynamic> parse(String raw) {
    if (raw.length > 16384) throw const ToolFailure('invalidArguments');
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const ToolFailure('invalidJson');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ToolFailure('invalidArguments');
    }
    final schema = this.schema;
    if (schema != null) {
      if (!JsonSchemaLite.valid(schema, decoded)) {
        throw const ToolFailure('invalidArguments');
      }
      return decoded;
    }
    if (decoded.keys.any((k) => !fields.containsKey(k)) ||
        fields.entries.any(
          (f) => decoded.containsKey(f.key)
              ? !f.value.valid(decoded[f.key])
              : f.value.required,
        )) {
      throw const ToolFailure('invalidArguments');
    }
    return decoded;
  }
}

/// Outcome of the plugin/AI policy check for one tool. Codes are returned to
/// the model as structured errors under the original call id.
enum ToolDecision {
  allowed,
  capabilityUnavailable,
  policyChanged,
  permissionDenied,
}

/// Host policy over registered tools (plugin switches, AI scope). It never
/// adds tools; it only narrows the registered set, and is re-checked by the
/// gateway right before execution because model-side tool lists go stale.
abstract interface class ToolPolicy {
  /// Increments whenever plugin, instance or AI-scope state changes.
  int get revision;
  ToolDecision decide(String tool);
}

class ToolRegistry {
  /// Upper bound of tools offered to a model in one request. Registration
  /// fails beyond it, so no tool is ever silently truncated away.
  /// Built-in: media 18 (incl. set subtitle) + processing 10 (incl. save to
  /// source) + subtitles 6 + plugin status 1 = 35; the rest is room for
  /// external (MCP) tools. Mainstream model APIs accept over a hundred.
  static const maxTools = 96;
  final _tools = <String, RegisteredTool>{};

  /// Installed by the Plugin Manager; null allows every registered tool.
  ToolPolicy? policy;
  Iterable<String> get names => _tools.keys;
  ToolDecision decide(String name) =>
      policy?.decide(name) ?? ToolDecision.allowed;
  void register(RegisteredTool tool) {
    if (_tools.containsKey(tool.name)) throw ArgumentError('Duplicate tool');
    if (_tools.length >= maxTools) throw StateError('Tool limit exceeded');
    _tools[tool.name] = tool;
  }

  /// Removes a dynamically registered (external) tool.
  void unregister(String name) => _tools.remove(name);

  RegisteredTool? operator [](String name) => _tools[name];
  List<ModelTool> get available => _tools.values
      .where(
        (t) =>
            (t.available?.call() ?? true) &&
            decide(t.name) == ToolDecision.allowed,
      )
      .map((t) => t.model)
      .toList();
}

class ToolResult {
  const ToolResult(
    this.callId,
    this.status, {
    this.data = const {},
    this.error,
    this.retryable = false,
  });
  final String callId;
  final String status;
  final Map<String, dynamic> data;
  final String? error;
  final bool retryable;
  Map<String, dynamic> toJson() => {
    'call_id': callId,
    'status': status,
    'data': data,
    if (error != null) 'error_code': error,
    'retryable': retryable,
  };
}

abstract interface class ToolJournal {
  ToolResult? previous(String operation, String callId);
  void record(String operation, ToolResult result);
}

/// Operation identity belongs to the host turn, independent of vendor call IDs.
/// Failed/unknown writes stay cached and are never blindly retried.
class ToolGateway {
  ToolGateway(
    this.registry, {
    this.timeout = const Duration(seconds: 20),
    this.journal,
  });
  final ToolJournal? journal;
  final ToolRegistry registry;
  final Duration timeout;
  final _operations = <String, Future<ToolResult>>{};
  final _lastIntent = <String, String>{};
  final _intentVersion = <String, int>{};
  final _uncertain = <String, ToolResult>{};
  void finishTurn(String turn) {
    _operations.removeWhere((key, _) => key.startsWith('$turn:'));
    _uncertain.removeWhere((key, _) => key.startsWith('$turn:'));
    _lastIntent.remove(turn);
    _intentVersion.remove(turn);
  }

  Future<ToolResult> invoke({
    required String turn,
    required ModelToolCall call,
    required Set<String> allowed,
    required bool Function() active,
    required Future<bool> Function(String, Map<String, dynamic>) confirm,
    void Function(Map<String, dynamic>)? progress,
  }) async {
    try {
      if (!active()) return ToolResult(call.id, 'cancelled');
      final tool = registry[call.name];
      if (tool == null || !allowed.contains(call.name)) {
        throw const ToolFailure('unknownTool');
      }
      if (!(tool.available?.call() ?? true)) {
        throw const ToolFailure('unavailable');
      }
      // An old tool list is no execution permit: re-check current policy.
      final decision = registry.decide(tool.name);
      if (decision != ToolDecision.allowed) throw ToolFailure(decision.name);
      final args = tool.parse(call.arguments);
      final canonical = <String, dynamic>{
        for (final k in (args.keys.toList()..sort())) k: args[k],
      };
      final digest = sha256.convert(utf8.encode(jsonEncode(canonical)));
      final identity = '${call.name}:$digest';
      if (!tool.readOnly && _lastIntent[turn] != identity) {
        _lastIntent[turn] = identity;
        _intentVersion[turn] = (_intentVersion[turn] ?? -1) + 1;
      }
      // Intervening writes create a new intent: pause/resume/pause must really
      // pause twice. Consecutive duplicates retain the same host operation.
      final operation = '$turn:${_intentVersion[turn] ?? 0}:$identity';
      final unknown = _uncertain['$turn:$identity'];
      if (!tool.readOnly && unknown != null) {
        return ToolResult(call.id, 'failed', error: unknown.error);
      }
      // Queries must reflect current state after playback changes.
      if (!tool.readOnly && _operations.containsKey(operation)) {
        final result = await _operations[operation]!;
        return ToolResult(
          call.id,
          result.status,
          data: result.data,
          error: result.error,
          retryable: result.retryable,
        );
      }
      if (!tool.readOnly) {
        final recorded = journal?.previous(operation, call.id);
        if (recorded != null) return recorded;
        journal?.record(operation, ToolResult(call.id, 'pending'));
      }
      final future = _execute(tool, args, call.id, active, confirm, progress)
          .then((result) {
            if (!tool.readOnly) {
              journal?.record(operation, result);
              if (result.error == 'executionUnknown') {
                _uncertain['$turn:$identity'] = result;
              }
            }
            return result;
          });
      if (!tool.readOnly) _operations[operation] = future;
      return await future;
    } on ToolFailure catch (e) {
      return ToolResult(call.id, 'failed', error: e.code);
    } catch (_) {
      return ToolResult(call.id, 'failed', error: 'businessFailure');
    }
  }

  Future<ToolResult> _execute(
    RegisteredTool tool,
    Map<String, dynamic> args,
    String callId,
    bool Function() active,
    Future<bool> Function(String, Map<String, dynamic>) confirm,
    void Function(Map<String, dynamic>)? progress,
  ) async {
    var running = true;
    try {
      final revision = registry.policy?.revision;
      if (tool.confirmation && !await confirm(tool.name, args)) {
        return ToolResult(callId, 'cancelled');
      }
      if (!active()) return ToolResult(callId, 'cancelled');
      if (!(tool.available?.call() ?? true)) {
        throw const ToolFailure('unavailable');
      }
      final decision = registry.decide(tool.name);
      if (decision != ToolDecision.allowed) throw ToolFailure(decision.name);
      // A confirmation is bound to the policy it was given under: plugin,
      // instance or AI-scope changes while the card was open void it.
      if (tool.confirmation && registry.policy?.revision != revision) {
        throw const ToolFailure('policyChanged');
      }
      final data = await ToolExecution.run(
        () => tool.execute(args),
        () => running && active(),
        progress: progress,
      ).timeout(tool.timeout ?? timeout);
      // Each business binding returns an explicit allowlist of fields.
      if (jsonEncode(data).length > 24000) {
        throw const ToolFailure('resultTooLarge');
      }
      return ToolResult(callId, 'success', data: data);
    } on TimeoutException {
      return ToolResult(callId, 'failed', error: 'executionUnknown');
    } on ToolFailure catch (e) {
      return ToolResult(callId, 'failed', error: e.code);
    } catch (_) {
      return ToolResult(callId, 'failed', error: 'businessFailure');
    } finally {
      running = false;
    }
  }
}
