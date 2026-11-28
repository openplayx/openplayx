import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/assistant/plugins/external/external_tools.dart';
import 'package:openplayx/assistant/plugins/tools/json_schema_lite.dart';
import 'package:openplayx/assistant/plugins/tools/tool_registry.dart';
import 'package:openplayx/assistant/plugins/external/external_service_registry.dart';
import 'package:openplayx/assistant/plugins/external/external_service_setup.dart';
import 'package:sqlite3/sqlite3.dart';

const _searchSchema = {
  'type': 'object',
  'properties': {
    'query': {'type': 'string', 'minLength': 1, 'maxLength': 50},
    'page': {'type': 'integer', 'minimum': 1, 'default': 1},
  },
  'required': ['query'],
  'additionalProperties': false,
};

/// Session-based fake MCP server: initialize issues a session id, later
/// requests must carry it; [expireOnce] answers 404 once to force re-init.
class FakeServer {
  late HttpServer server;
  var sessions = 0;
  var expireOnce = false;
  final calls = <Map<String, dynamic>>[];

  String get url => 'http://127.0.0.1:${server.port}';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(_handle);
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    if (req.headers.value('authorization') != 'Bearer good') {
      res.statusCode = 401;
      return res.close();
    }
    final msg = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
    if (msg['id'] == null) {
      res.statusCode = 202;
      return res.close();
    }
    final method = msg['method'];
    if (method != 'initialize') {
      final session = req.headers.value('mcp-session-id');
      if (session != 's$sessions' || expireOnce) {
        expireOnce = false;
        res.statusCode = 404;
        return res.close();
      }
    }
    Object result;
    switch (method) {
      case 'initialize':
        sessions++;
        res.headers.set('Mcp-Session-Id', 's$sessions');
        result = {
          'protocolVersion': '2025-11-25',
          'capabilities': {'tools': <String, Object?>{}},
          'serverInfo': {
            'name': 'fake',
            'title': 'Fake Search',
            'version': '1',
          },
        };
      case 'tools/list':
        result = {
          'tools': [
            {
              'name': 'search',
              'description': 'Search things.',
              'inputSchema': _searchSchema,
              'annotations': {'readOnlyHint': true},
            },
            {
              'name': 'start_download',
              'description': 'Starts a download.',
              'inputSchema': {
                'type': 'object',
                'properties': {
                  'plan_ref': {'type': 'string'},
                },
                'required': ['plan_ref'],
              },
            },
            {
              'name': 'fancy',
              'inputSchema': {
                'type': 'object',
                'oneOf': [
                  {
                    'required': ['a'],
                  },
                ],
              },
            },
          ],
        };
      default:
        final params = msg['params'] as Map;
        calls.add(Map<String, dynamic>.from(params));
        final args = params['arguments'] as Map;
        result = args['query'] == 'fail'
            ? {
                'content': [
                  {'type': 'text', 'text': 'nope'},
                ],
                'structuredContent': {
                  'error': {'code': 'upstream_timeout'},
                },
                'isError': true,
              }
            : {
                'content': [
                  {'type': 'text', 'text': '{}'},
                ],
                'structuredContent': {
                  'items': [
                    for (var i = 0; i < 3; i++) {'title': 'Result $i'},
                  ],
                },
                'isError': false,
              };
    }
    // Answer as an SSE stream to exercise that path too.
    res.headers.contentType = ContentType('text', 'event-stream');
    res.write(
      'event: message\ndata: ${jsonEncode({'jsonrpc': '2.0', 'id': msg['id'], 'result': result})}\n\n',
    );
    await res.close();
  }
}

ModelToolCall _call(String name, Map<String, dynamic> args) =>
    ModelToolCall('c-$name', name, jsonEncode(args));

void main() {
  group('JsonSchemaLite', () {
    test('accepts the common subset and validates values', () {
      expect(JsonSchemaLite.unsupported(_searchSchema), isNull);
      expect(JsonSchemaLite.valid(_searchSchema, {'query': 'x'}), isTrue);
      expect(JsonSchemaLite.valid(_searchSchema, {'query': ''}), isFalse);
      expect(JsonSchemaLite.valid(_searchSchema, {'page': 1}), isFalse);
      expect(
        JsonSchemaLite.valid(_searchSchema, {'query': 'x', 'page': 0}),
        isFalse,
      );
      expect(
        JsonSchemaLite.valid(_searchSchema, {'query': 'x', 'extra': 1}),
        isFalse,
      );
      final nested = {
        'type': 'object',
        'properties': {
          'tags': {
            'type': 'array',
            'items': {
              'type': 'string',
              'enum': ['a', 'b'],
            },
            'maxItems': 2,
          },
        },
      };
      expect(JsonSchemaLite.unsupported(nested), isNull);
      expect(
        JsonSchemaLite.valid(nested, {
          'tags': ['a'],
        }),
        isTrue,
      );
      expect(
        JsonSchemaLite.valid(nested, {
          'tags': ['c'],
        }),
        isFalse,
      );
    });

    test('reports keywords outside the subset instead of ignoring them', () {
      expect(
        JsonSchemaLite.unsupported({
          'type': 'object',
          'anyOf': [<String, Object?>{}],
        }),
        'unsupported keyword: anyOf',
      );
      expect(
        JsonSchemaLite.unsupported({
          'type': 'object',
          'properties': {
            'x': {r'$ref': '#/defs/x'},
          },
        }),
        r'unsupported keyword: $ref',
      );
    });
  });

  group('ExternalTools', () {
    late FakeServer fake;
    late ExternalServiceRegistry services;
    late ExternalServiceSetup setup;
    late ToolRegistry registry;
    late ExternalTools tools;

    setUp(() async {
      fake = FakeServer();
      await fake.start();
      services = ExternalServiceRegistry(db: sqlite3.openInMemory());
      setup = ExternalServiceSetup(registry: services);
      registry = ToolRegistry();
      tools = ExternalTools(registry: registry, setup: setup);
      await tools.start(recheck: false);
    });
    tearDown(() async {
      tools.dispose();
      await fake.server.close(force: true);
    });

    Future<ExternalService> add() async {
      final probe = await setup.probe(fake.url, 'good');
      return setup.save(probe, 'good', name: '测试搜索');
    }

    test('registers each tool under a service alias with its own schema and '
        'forwards calls over MCP', () async {
      final s = await add();
      await Future<void>.delayed(Duration.zero);
      final search = ExternalTools.alias(s, 'search');
      final start = ExternalTools.alias(s, 'start_download');
      expect(search, startsWith('mcp_'));
      final offered = {for (final t in registry.available) t.name: t};
      expect(offered.keys, containsAll([search, start]));
      expect(offered[search]!.schema, _searchSchema);
      expect(offered[search]!.description, contains('测试搜索'));
      // A schema outside the subset is not offered, with a reason.
      expect(tools.unsupported[s.id]!['fancy'], 'unsupported keyword: oneOf');
      expect(registry[ExternalTools.alias(s, 'fancy')], isNull);
      // Read-only tools run directly; others ask the user first.
      expect(registry[search]!.confirmation, isFalse);
      expect(registry[start]!.confirmation, isTrue);
      expect(tools.describe(start), '测试搜索 · start_download');

      final gateway = ToolGateway(registry);
      Future<ToolResult> invoke(String name, Map<String, dynamic> args) =>
          gateway.invoke(
            turn: 't',
            call: _call(name, args),
            allowed: {search, start},
            active: () => true,
            confirm: (_, _) async => true,
          );
      final ok = await invoke(search, {'query': 'ubuntu'});
      expect(ok.status, 'success');
      expect((ok.data['items'] as List).length, 3);
      expect(fake.calls.single, {
        'name': 'search',
        'arguments': {'query': 'ubuntu'},
      });
      // Arguments are checked against the tool's schema before sending.
      final bad = await invoke(search, {'query': 'x', 'magnet': 'y'});
      expect(bad.error, 'invalidArguments');
      expect(fake.calls, hasLength(1));
      // Service errors keep their code.
      final failed = await invoke(search, {'query': 'fail'});
      expect(failed.error, 'upstream_timeout');
      // An expired session is re-initialised transparently.
      final before = fake.sessions;
      fake.expireOnce = true;
      final again = await invoke(search, {'query': 'again'});
      expect(again.status, 'success');
      expect(fake.sessions, before + 1);
    });

    test(
      'Torrent aliases keep their original identifiers and MCP routing',
      () async {
        const names = ['list_destinations', 'create_plan'];
        final service = ExternalService(
          id: 'torrent',
          name: 'Torrent',
          baseUrl: fake.url,
          endpoint: fake.url,
          serverName: 'openplayx-bittorrent',
          available: true,
          tools: names,
          toolDefs: [
            for (final name in names)
              {
                'name': name,
                'inputSchema': {'type': 'object'},
                'annotations': {'readOnlyHint': true},
              },
          ],
        );
        await services.save(service, token: 'good');
        tools.sync();

        final gateway = ToolGateway(registry);
        for (final name in names) {
          final alias = ExternalTools.alias(service, name);
          expect(alias, 'mcp_orrent_$name');
          final call = _call(alias, {});
          final result = await gateway.invoke(
            turn: 'torrent',
            call: call,
            allowed: {alias},
            active: () => true,
            confirm: (_, _) async => true,
          );
          expect(result.status, 'success');
          expect(call.name, alias);
          expect(fake.calls.last, {'name': name, 'arguments': <String, Object?>{}});
        }
      },
    );

    test('download queries bypass confirmation under their MCP alias while '
        'writes require approval before reaching the server', () async {
      const arguments = <String, Map<String, dynamic>>{
        'get_download': {'task_id': 'task-1'},
        'start_download': {'plan_ref': 'download-plan'},
        'pause': {'task_id': 'task-1'},
        'resume': {'task_id': 'task-1'},
        'remove': {'task_id': 'task-1', 'plan_ref': 'remove-plan'},
      };
      final service = ExternalService(
        id: 'torrent',
        name: 'VM BitTorrent',
        baseUrl: fake.url,
        endpoint: fake.url,
        serverName: 'openplayx-bittorrent',
        available: true,
        tools: arguments.keys.toList(),
        toolDefs: [
          for (final name in arguments.keys)
            {
              'name': name,
              'inputSchema': {
                'type': 'object',
                'properties': {
                  for (final key in arguments[name]!.keys)
                    key: {'type': 'string'},
                },
                'required': arguments[name]!.keys.toList(),
                'additionalProperties': false,
              },
              'annotations': {
                'readOnlyHint': name == 'get_download',
                'destructiveHint': name == 'remove',
                'idempotentHint': name != 'remove',
              },
            },
        ],
      );
      await services.save(service, token: 'good');
      tools.sync();

      final gateway = ToolGateway(registry);
      for (final entry in arguments.entries) {
        final alias = ExternalTools.alias(service, entry.key);
        final readOnly = entry.key == 'get_download';
        expect(alias, 'mcp_orrent_${entry.key}');
        expect(registry[alias]!.readOnly, readOnly);
        expect(registry[alias]!.confirmation, !readOnly);
        var confirmations = 0;
        Future<ToolResult> invoke(String turn, bool approve) => gateway.invoke(
          turn: turn,
          call: _call(alias, entry.value),
          allowed: {alias},
          active: () => true,
          confirm: (name, args) async {
            confirmations++;
            expect(name, alias);
            expect(args, entry.value);
            return approve;
          },
        );

        final before = fake.calls.length;
        final denied = await invoke('deny-${entry.key}', false);
        expect(denied.status, readOnly ? 'success' : 'cancelled');
        expect(confirmations, readOnly ? 0 : 1);
        expect(fake.calls.length, before + (readOnly ? 1 : 0));

        final accepted = await invoke('approve-${entry.key}', true);
        expect(accepted.status, 'success');
        expect(confirmations, readOnly ? 0 : 2);
        expect(fake.calls.length, before + (readOnly ? 2 : 1));
        expect(fake.calls.last, {'name': entry.key, 'arguments': entry.value});
      }
    });

    test('removing a service withdraws its tools', () async {
      final s = await add();
      await Future<void>.delayed(Duration.zero);
      final search = ExternalTools.alias(s, 'search');
      expect(registry[search], isNotNull);
      await services.remove(s.id);
      await Future<void>.delayed(Duration.zero);
      expect(registry[search], isNull);
      expect(registry.available, isEmpty);
    });

    test('an unavailable service is not offered', () async {
      final s = await add();
      await services.save(s.copyWith(available: false));
      await Future<void>.delayed(Duration.zero);
      expect(registry.available, isEmpty);
    });

    test('oversized results are trimmed, not failed', () {
      final big = {
        'items': [
          for (var i = 0; i < 2000; i++) {'title': 'x' * 40, 'i': i},
        ],
      };
      final fitted = ExternalTools.fit(big);
      expect(jsonEncode(fitted).length, lessThanOrEqualTo(20000));
      expect(fitted['_truncated'], isTrue);
      expect((fitted['items'] as List), isNotEmpty);
    });
  });
}
