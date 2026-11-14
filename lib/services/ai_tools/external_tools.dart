import 'dart:async';
import 'dart:convert';

import '../external/external_service_registry.dart';
import '../external/external_service_setup.dart';
import '../external/mcp_client.dart';
import 'json_schema_lite.dart';
import 'tool_registry.dart';

/// Offers the tools of user-configured external services (外部能力, MCP over
/// Streamable HTTP) to the assistant and forwards calls to them.
///
/// Each tool is registered under a host alias `mcp_<service>_<tool>` so
/// services never shadow built-in tools or each other. Its own input schema
/// is passed to the model and checked before every call; a schema outside
/// [JsonSchemaLite] leaves the tool unregistered with a recorded reason.
/// Tools not marked read-only ask the user to confirm in the chat first.
class ExternalTools {
  ExternalTools({
    required this.registry,
    required this.setup,
    this.canExecute,
    McpClient Function(Uri endpoint, String token)? client,
  }) : _newClient = client ?? _defaultClient;

  final ToolRegistry registry;
  final ExternalServiceSetup setup;
  final bool Function()? canExecute;
  final McpClient Function(Uri endpoint, String token) _newClient;

  static McpClient _defaultClient(Uri endpoint, String token) =>
      McpClient(endpoint: endpoint, token: token);

  ExternalServiceRegistry get services => setup.registry;

  /// Registered alias → (service id, original tool name).
  final _aliases = <String, (String, String)>{};
  final _clients = <String, (String, McpClient)>{};

  /// Service id → tool name → why it is not offered.
  final unsupported = <String, Map<String, String>>{};
  StreamSubscription<void>? _changes;

  static const _resultLimit = 20000;

  /// Loads services, registers their tools and keeps them in sync. Every
  /// service is re-checked in the background so tools and status are fresh.
  Future<void> start({bool recheck = true}) async {
    if (!services.loaded) await services.load();
    sync();
    _changes ??= services.changes.stream.listen((_) => sync());
    if (recheck) {
      for (final s in services.services) {
        unawaited(setup.recheck(s).then((_) {}, onError: (_) {}));
      }
    }
  }

  void dispose() {
    _changes?.cancel();
    for (final (_, c) in _clients.values) {
      c.close();
    }
    _clients.clear();
  }

  static String _slug(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  /// Stable, model-safe alias for [tool] of [service].
  static String alias(ExternalService service, String tool) {
    final id = service.id.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final short = id.length > 6 ? id.substring(id.length - 6) : id;
    final name = 'mcp_${short}_${_slug(tool)}'.replaceAll(RegExp('_+'), '_');
    return name.length > 64 ? name.substring(0, 64) : name;
  }

  /// The service a registered alias belongs to (for confirmation cards).
  String? describe(String alias) {
    final target = _aliases[alias];
    if (target == null) return null;
    final s = services.get(target.$1);
    return s == null ? null : '${s.name} · ${target.$2}';
  }

  void sync() {
    for (final name in _aliases.keys) {
      registry.unregister(name);
    }
    _aliases.clear();
    unsupported.clear();
    final ids = {for (final s in services.services) s.id};
    _clients.removeWhere((id, entry) {
      final s = services.get(id);
      final stale = !ids.contains(id) || s?.endpoint != entry.$1;
      if (stale) entry.$2.close();
      return stale;
    });
    for (final s in services.services) {
      for (final def in s.toolDefs) {
        final tool = def['name'];
        if (tool is! String) continue;
        final reason = _register(s, tool, def);
        if (reason != null) (unsupported[s.id] ??= {})[tool] = reason;
      }
    }
  }

  String? _register(ExternalService s, String tool, Map<String, dynamic> def) {
    final raw = def['inputSchema'];
    final schema = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{'type': 'object'};
    schema['type'] ??= 'object';
    if (schema['type'] != 'object') return 'input is not an object';
    final problem = JsonSchemaLite.unsupported(schema);
    if (problem != null) return problem;
    final name = alias(s, tool);
    if (_aliases.containsKey(name) || registry[name] != null) {
      return 'name conflict';
    }
    final annotations = def['annotations'] is Map
        ? def['annotations'] as Map
        : const {};
    final readOnly = annotations['readOnlyHint'] == true;
    final text = def['description'] is String
        ? def['description'] as String
        : (def['title'] as String? ?? tool);
    final description = '[外部能力：${s.name}] $text';
    final id = s.id;
    try {
      registry.register(
        RegisteredTool(
          name,
          description.length > 1000
              ? description.substring(0, 1000)
              : description,
          const {},
          (args) => _call(id, tool, args),
          schema: schema,
          readOnly: readOnly,
          confirmation: !readOnly,
          available: () => services.get(id)?.available ?? false,
          timeout: const Duration(seconds: 75),
        ),
      );
    } on StateError {
      return 'tool limit reached';
    } on ArgumentError {
      return 'unsupported definition';
    }
    _aliases[name] = (id, tool);
    return null;
  }

  Future<McpClient> _client(ExternalService s) async {
    final existing = _clients[s.id];
    if (existing != null && existing.$1 == s.endpoint) return existing.$2;
    existing?.$2.close();
    final token = await services.token(s.id);
    if (token == null || token.isEmpty) {
      throw const ToolFailure('external_token_missing');
    }
    final client = _newClient(Uri.parse(s.endpoint), token);
    _clients[s.id] = (s.endpoint, client);
    return client;
  }

  Future<Map<String, dynamic>> _call(
    String serviceId,
    String tool,
    Map<String, dynamic> args,
  ) async {
    if (!ToolExecution.active || !(canExecute?.call() ?? true)) {
      throw const ToolFailure('cancelled');
    }
    final s = services.get(serviceId);
    if (s == null) throw const ToolFailure('external_service_removed');
    final Map<String, dynamic> result;
    try {
      result = await (await _client(s)).callTool(tool, args);
    } on McpException catch (e) {
      throw ToolFailure('external_${e.code}');
    }
    final structured = result['structuredContent'];
    final text = [
      for (final c in (result['content'] as List? ?? const []))
        if (c is Map && c['type'] == 'text' && c['text'] is String) c['text'],
    ].join('\n');
    if (result['isError'] == true) {
      final error = structured is Map ? structured['error'] : null;
      final code = error is Map ? error['code'] : null;
      throw ToolFailure(
        code is String && RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(code)
            ? code
            : 'external_tool_error',
      );
    }
    final data = structured is Map
        ? Map<String, dynamic>.from(structured)
        : <String, dynamic>{'text': text};
    return fit(data);
  }

  /// Keeps a result within the gateway's size limit by trimming its longest
  /// lists (marked `_truncated`) instead of failing the call.
  static Map<String, dynamic> fit(Map<String, dynamic> data) {
    if (jsonEncode(data).length <= _resultLimit) return data;
    final out = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    List<dynamic>? longest(Object? node) {
      List<dynamic>? best;
      void walk(Object? n) {
        if (n is List) {
          if (best == null || n.length > best!.length) best = n;
          n.forEach(walk);
        } else if (n is Map) {
          n.values.forEach(walk);
        }
      }

      walk(node);
      return best;
    }

    for (var i = 0; i < 500 && jsonEncode(out).length > _resultLimit; i++) {
      final list = longest(out);
      if (list == null || list.isEmpty) break;
      list.removeRange((list.length / 2).ceil(), list.length);
      out['_truncated'] = true;
    }
    if (jsonEncode(out).length > _resultLimit) {
      final text = jsonEncode(data);
      return {
        'text': text.substring(0, _resultLimit - 200),
        '_truncated': true,
      };
    }
    return out;
  }
}
