import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/services/external/external_service_setup.dart';
import 'package:openplayx/services/external/external_service_registry.dart';
import 'package:sqlite3/sqlite3.dart';

/// A tiny MCP server: [path] answers JSON-RPC as [name]; every other path
/// behaves like a WebUI that refuses unauthenticated requests.
Future<HttpServer> fakeMcp(String path, String name) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final res = req.response;
    if (req.uri.path != path) {
      res.statusCode = 403;
      res.write('<html>Forbidden</html>');
      await res.close();
      return;
    }
    if (req.headers.value('authorization') != 'Bearer good') {
      res.statusCode = 401;
      await res.close();
      return;
    }
    final msg = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
    final result = switch (msg['method']) {
      'initialize' => {
        'protocolVersion': '2025-11-25',
        'capabilities': {'tools': {}},
        'serverInfo': {'name': name, 'title': 'Fake $name', 'version': '9'},
      },
      'tools/list' => {
        'tools': [
          {'name': 'search'},
          {'name': 'get_details'},
        ],
      },
      _ => {},
    };
    res.headers.contentType = ContentType.json;
    res.write(
      jsonEncode({'jsonrpc': '2.0', 'id': msg['id'], 'result': result}),
    );
    await res.close();
  });
  return server;
}

void main() {
  late Database db;
  late ExternalServiceRegistry registry;
  late ExternalServiceSetup setup;

  setUp(() {
    db = sqlite3.openInMemory();
    registry = ExternalServiceRegistry(db: db);
    setup = ExternalServiceSetup(registry: registry);
  });

  test('saves any MCP service with its tools and token', () async {
    final server = await fakeMcp('/mcp', 'openplayx-torrent-search');
    addTearDown(() => server.close(force: true));
    final url = 'http://127.0.0.1:${server.port}';
    final probe = await setup.probe('$url/mcp/', 'good');
    expect(probe.baseUrl, url);
    expect(probe.endpoint, '$url/mcp');
    expect(probe.title, 'Fake openplayx-torrent-search');
    expect(probe.tools, ['search', 'get_details']);
    final saved = await setup.save(probe, 'good', name: '家里搜索');
    expect(registry.services.single.name, '家里搜索');
    expect(registry.services.single.available, isTrue);
    expect(await registry.token(saved.id), 'good');
    // The same address again updates instead of duplicating.
    await setup.save(probe, 'good');
    expect(registry.services, hasLength(1));
    expect(registry.services.single.name, '家里搜索');
    // Persisted across a reload.
    final reloaded = ExternalServiceRegistry(db: db);
    await reloaded.load();
    expect(reloaded.services.single.tools, ['search', 'get_details']);
  });

  test('finds /api/mcp despite a WebUI refusing /mcp; unknown services are '
      'accepted too', () async {
    final server = await fakeMcp('/api/mcp', 'someone-else');
    addTearDown(() => server.close(force: true));
    final url = 'http://127.0.0.1:${server.port}';
    final probe = await setup.probe(url, 'good');
    expect(probe.endpoint, '$url/api/mcp');
    expect(probe.serverName, 'someone-else');
  });

  test('re-check marks an unreachable service unavailable', () async {
    final server = await fakeMcp('/mcp', 'openplayx-bittorrent');
    final url = 'http://127.0.0.1:${server.port}';
    final saved = await setup.save(await setup.probe(url, 'good'), 'good');
    await server.close(force: true);
    await expectLater(
      setup.recheck(saved),
      throwsA(isA<ExternalServiceException>()),
    );
    expect(registry.get(saved.id)!.available, isFalse);
  });

  test('reports wrong tokens and bad addresses', () async {
    final server = await fakeMcp('/mcp', 'someone-else');
    addTearDown(() => server.close(force: true));
    final url = 'http://127.0.0.1:${server.port}';
    expect(
      () => setup.probe(url, 'bad'),
      throwsA(
        isA<ExternalServiceException>().having((e) => e.message, 'm', '访问令牌无效'),
      ),
    );
    expect(
      () => setup.probe('http://example.com', 'good'),
      throwsA(isA<ExternalServiceException>()),
    );
    expect(
      () => setup.probe('https://x.test/some/path', 'good'),
      throwsA(isA<ExternalServiceException>()),
    );
    expect(
      () => setup.probe(url, ''),
      throwsA(isA<ExternalServiceException>()),
    );
  });

  test('edits keep the row in place; removal persists', () async {
    for (final (id, name) in [('ext-a', '下载'), ('ext-b', '搜索')]) {
      await registry.save(
        ExternalService(
          id: id,
          name: name,
          baseUrl: 'https://$id.test',
          endpoint: 'https://$id.test/mcp',
          serverName: 'srv',
          tools: const ['search'],
        ),
      );
    }
    await registry.save(registry.services.first.copyWith(name: '家里下载'));
    expect([for (final s in registry.services) s.name], ['家里下载', '搜索']);
    await registry.remove('ext-b');
    final reloaded = ExternalServiceRegistry(db: db);
    await reloaded.load();
    expect([for (final s in reloaded.services) s.id], ['ext-a']);
    expect(reloaded.services.single.tools, ['search']);
  });

  test('plain HTTP is limited to LAN hosts', () {
    for (final h in ['localhost', '192.168.1.211', '10.0.0.2', 'nas.local']) {
      expect(ExternalServiceSetup.isLanHost(h), isTrue, reason: h);
    }
    for (final h in ['example.com', '8.8.8.8', '172.32.0.1']) {
      expect(ExternalServiceSetup.isLanHost(h), isFalse, reason: h);
    }
  });
}
