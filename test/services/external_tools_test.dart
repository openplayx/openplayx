import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/services/ai_tools/external_tools.dart';
import 'package:openplayx/services/ai_tools/json_schema_lite.dart';
import 'package:openplayx/services/ai_tools/tool_registry.dart';
import 'package:openplayx/services/external/external_service_registry.dart';
import 'package:openplayx/services/external/external_service_setup.dart';
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
          'capabilities': {'tools': {}},
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
          'anyOf': [{}],
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
