import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/assistant/plugins/tools/tool_registry.dart';
import 'package:openplayx/assistant/plugins/web/web_tools.dart';
import 'package:openplayx/data/configuration/configuration_database.dart';
import 'package:openplayx/assistant/plugins/external/external_tools.dart';
import 'package:openplayx/assistant/plugins/external/external_presets.dart';
import 'package:openplayx/assistant/plugins/external/external_service_registry.dart';
import 'package:openplayx/assistant/plugins/external/external_service_setup.dart';
import 'package:openplayx/assistant/plugins/web/page_reader.dart';
import 'package:openplayx/assistant/plugins/web/safe_http.dart';
import 'package:sqlite3/sqlite3.dart';

const _article = '''
<html><head><title>Ignored</title><meta property="og:title" content="Release notes"></head>
<body>
<nav><a href="/">Home</a> <a href="/about">About</a></nav>
<header>Site header</header>
<article>
  <h1>Version 2.0</h1>
  <p>This release adds <strong>web search</strong> and a <a href="/docs/fetch">fetch tool</a>. It also contains many smaller fixes that make the whole thing faster.</p>
  <ul><li>First item</li><li>Second <code>item</code></li></ul>
  <pre>void main() {
  print('hi');
}</pre>
  <table><tr><th>Name</th><th>Value</th></tr><tr><td>a</td><td>1</td></tr></table>
  <script>alert('x')</script>
</article>
<footer>Copyright</footer>
</body></html>
''';

void main() {
  group('SafeHttp.isPublic', () {
    bool pub(String a) => SafeHttp.isPublic(InternetAddress(a));
    test('rejects local and private ranges', () {
      for (final a in [
        '127.0.0.1',
        '10.1.2.3',
        '172.16.0.1',
        '172.31.255.255',
        '192.168.1.211',
        '169.254.169.254',
        '100.64.0.1',
        '0.0.0.0',
        '224.0.0.1',
        '255.255.255.255',
        '::1',
        '::',
        'fe80::1',
        'fd00::1',
        '::ffff:192.168.1.1',
        '::ffff:127.0.0.1',
        '64:ff9b::a00:1',
      ]) {
        expect(pub(a), isFalse, reason: a);
      }
    });
    test('accepts public addresses', () {
      for (final a in [
        '8.8.8.8',
        '1.1.1.1',
        '172.32.0.1',
        '100.128.0.1',
        '2606:4700:4700::1111',
        '::ffff:8.8.8.8',
      ]) {
        expect(pub(a), isTrue, reason: a);
      }
    });
    test('refuses private hosts and non-http schemes', () async {
      final http = SafeHttp();
      for (final url in [
        'http://127.0.0.1:1/',
        'http://localhost/',
        'http://[::1]/',
        'http://192.168.1.1/admin',
      ]) {
        await expectLater(
          http.request(Uri.parse(url)),
          throwsA(
            isA<WebException>().having(
              (e) => e.code,
              'code',
              anyOf('blockedAddress', 'dnsFailed'),
            ),
          ),
          reason: url,
        );
      }
      await expectLater(
        http.request(Uri.parse('file:///etc/passwd')),
        throwsA(isA<WebException>()),
      );
    });
  });

  group('preset 联网搜索 (mcp-tavily)', () {
    late Database db;
    late ExternalServiceRegistry services;
    setUp(() {
      db = sqlite3.openInMemory();
      services = ExternalServiceRegistry(db: db);
    });
    tearDown(() => db.close());

    test('is added once, with the install id as its token', () async {
      final id = InstallId(db);
      expect(await ExternalPresets.ensure(services, id), ['preset-tavily']);
      final s = services.get('preset-tavily')!;
      expect(s.endpoint, 'https://mcp-tavily.openplayx.com/mcp');
      expect(await services.token(s.id), id.value);
      expect(id.value, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(InstallId(db).value, id.value);
      expect(await ExternalPresets.ensure(services, id), isEmpty);
      expect(services.services, hasLength(1));
    });

    test('stays removed after the user removes it', () async {
      await ExternalPresets.ensure(services, InstallId(db));
      await services.remove('preset-tavily');
      expect(await ExternalPresets.ensure(services, InstallId(db)), isEmpty);
      expect(services.get('preset-tavily'), isNull);
    });

    test('offers mcp_tavily_web_search as a read-only tool', () async {
      await ExternalPresets.ensure(services, InstallId(db));
      final registry = ToolRegistry();
      final external = ExternalTools(
        registry: registry,
        setup: ExternalServiceSetup(registry: services),
      );
      addTearDown(external.dispose);
      await external.start(recheck: false);
      expect(external.unsupported, isEmpty);
      final tool = registry['mcp_tavily_web_search']!;
      expect(tool.readOnly, isTrue);
      expect(tool.confirmation, isFalse);
      expect(
        (tool.model.schema['properties'] as Map).keys,
        containsAll(['query', 'count', 'time_range']),
      );
    });

    test('install ids differ between installations', () {
      final other = sqlite3.openInMemory();
      addTearDown(other.close);
      ConfigurationDatabase.initialize(db);
      ConfigurationDatabase.initialize(other);
      expect(InstallId(db).value, isNot(InstallId(other).value));
    });
  });

  group('PageReader', () {
    test('extracts the article as Markdown', () {
      final page = PageReader.extract(
        _article,
        Uri.parse('https://example.com/news/2'),
      );
      expect(page.title, 'Release notes');
      final t = page.text;
      expect(t, startsWith('# Version 2.0'));
      expect(t, contains('**web search**'));
      expect(t, contains('[fetch tool](https://example.com/docs/fetch)'));
      expect(t, contains('- First item'));
      expect(t, contains('- Second `item`'));
      expect(t, contains("```\nvoid main() {\n  print('hi');\n}\n```"));
      expect(t, contains('| Name | Value |'));
      for (final gone in ['Home', 'Site header', 'Copyright', 'alert']) {
        expect(t, isNot(contains(gone)));
      }
    });

    test('fetches over HTTP, follows redirects, rejects binaries', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final res = req.response;
        switch (req.uri.path) {
          case '/old':
            await res.redirect(Uri.parse('/new'));
          case '/new':
            res.headers.contentType = ContentType.html;
            res.write(_article);
            await res.close();
          case '/bin':
            res.headers.contentType = ContentType.binary;
            res.add([0, 1, 2]);
            await res.close();
          default:
            res.statusCode = 404;
            await res.close();
        }
      });
      addTearDown(() => server.close(force: true));
      final base = 'http://127.0.0.1:${server.port}';
      final reader = PageReader(http: SafeHttp(allowPrivate: true));
      final page = await reader.read(Uri.parse('$base/old'));
      expect(page.url.path, '/new');
      expect(page.text, contains('Version 2.0'));
      await expectLater(
        reader.read(Uri.parse('$base/bin')),
        throwsA(
          isA<WebException>().having(
            (e) => e.code,
            'code',
            'unsupportedContent',
          ),
        ),
      );
      await expectLater(
        reader.read(Uri.parse('$base/missing')),
        throwsA(isA<WebException>().having((e) => e.code, 'code', 'http404')),
      );
    });
  });

  group('WebTools', () {
    test('registers read-only web_fetch and pages through content', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final long = List.generate(400, (i) => '<p>Paragraph number $i.</p>');
      server.listen((req) async {
        req.response.headers.contentType = ContentType.html;
        req.response.write('<html><body>${long.join()}</body></html>');
        await req.response.close();
      });
      addTearDown(() => server.close(force: true));
      final registry = ToolRegistry();
      WebTools(
        registry: registry,
        reader: PageReader(http: SafeHttp(allowPrivate: true)),
      );
      final gateway = ToolGateway(registry);
      Future<ToolResult> call(String name, Map<String, dynamic> args) =>
          gateway.invoke(
            turn: 't',
            call: ModelToolCall('c$name', name, jsonEncode(args)),
            allowed: registry.names.toSet(),
            active: () => true,
            confirm: (_, _) async => false, // read-only: never asked
          );

      expect(registry.names, ['web_fetch']);
      expect(registry['web_fetch']!.readOnly, isTrue);
      expect(registry['web_fetch']!.confirmation, isFalse);

      final url = 'http://127.0.0.1:${server.port}/';
      final first = await call('web_fetch', {'url': url, 'max_chars': 1000});
      expect(first.status, 'success');
      expect((first.data['content'] as String).length, 1000);
      final next = first.data['next_offset'] as int;
      final second = await call('web_fetch', {
        'url': url,
        'offset': next,
        'max_chars': 1000,
      });
      expect(second.data['offset'], next);
    });

    test('web_fetch refuses private addresses by default', () async {
      final registry = ToolRegistry();
      WebTools(registry: registry);
      final result = await ToolGateway(registry).invoke(
        turn: 't',
        call: const ModelToolCall(
          'c',
          'web_fetch',
          '{"url":"http://10.0.0.1/"}',
        ),
        allowed: registry.names.toSet(),
        active: () => true,
        confirm: (_, _) async => false,
      );
      expect(result.error, 'web_blockedAddress');
    });
  });
}
