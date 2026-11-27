import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/metadata/providers/tmdb_metadata_plugin.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';

class _RealHttp extends HttpOverrides {}

class _LocalRedirectClient implements HttpClient {
  _LocalRedirectClient(this.port)
    : _inner = HttpOverrides.runWithHttpOverrides(HttpClient.new, _RealHttp());
  final int port;
  final HttpClient _inner;

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _inner.getUrl(
    Uri.parse('http://127.0.0.1:$port${url.path}${url.hasQuery ? '?${url.query}' : ''}'),
  );

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('TmdbTransport handles 200, auth, 404, 429, 500, 418, bad JSON and close', () async {
    var nextStatus = 200;
    var nextBody = '{"ok":true}';
    String? nextRetryAfter;
    final seenAuth = <String?>[];

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      seenAuth.add(req.headers.value('authorization'));
      req.response.statusCode = nextStatus;
      if (nextRetryAfter != null) {
        req.response.headers.set('retry-after', nextRetryAfter);
      }
      req.response.write(nextBody);
      await req.response.close();
    });

    // Empty token rejected before network
    final empty = TmdbTransport('   ', client: _LocalRedirectClient(server.port));
    await expectLater(
      empty.get('/search/movie', {'query': 'test'}),
      throwsA(isA<PluginException>().having((e) => e.code, 'code', 'authRequired')),
    );
    empty.close();

    // Direct token mode 200
    final direct = TmdbTransport('my-secret', client: _LocalRedirectClient(server.port));
    final ok = await direct.get('/search/movie', {'query': 'dune'});
    expect(ok['ok'], isTrue);
    expect(seenAuth.last, 'Bearer my-secret');

    // Platform mode 200 (no auth header)
    final platform = TmdbTransport.platform(client: _LocalRedirectClient(server.port));
    final ok2 = await platform.get('/configuration', {});
    expect(ok2['ok'], isTrue);
    expect(seenAuth.last, isNull);

    // 401 -> authRequired
    nextStatus = 401;
    await expectLater(
      direct.get('/movie/1', {}),
      throwsA(isA<PluginException>().having((e) => e.code, 'code', 'authRequired')),
    );

    // 404 -> notFound
    nextStatus = 404;
    await expectLater(
      direct.get('/movie/999', {}),
      throwsA(isA<PluginException>().having((e) => e.code, 'code', 'notFound')),
    );

    // 429 with long Retry-After (>10s) fails immediately without waiting
    nextStatus = 429;
    nextRetryAfter = '60';
    await expectLater(
      direct.get('/movie/2', {}),
      throwsA(isA<PluginException>().having((e) => e.code, 'code', 'rateLimited')),
    );

    // 503 with long Retry-After (>10s) -> networkUnavailable
    nextStatus = 503;
    nextRetryAfter = '60';
    await expectLater(
      direct.get('/movie/3', {}),
      throwsA(isA<PluginException>().having((e) => e.code, 'code', 'networkUnavailable')),
    );

    // 418 -> providerError
    nextStatus = 418;
    nextRetryAfter = null;
    await expectLater(
      direct.get('/movie/4', {}),
      throwsA(isA<PluginException>().having((e) => e.code, 'code', 'providerError')),
    );

    // Bad JSON -> invalidMetadata
    nextStatus = 200;
    nextBody = 'not-json{{{';
    await expectLater(
      direct.get('/movie/5', {}),
      throwsA(isA<PluginException>().having((e) => e.code, 'code', 'invalidMetadata')),
    );

    // Oversized body > 4 MB -> quotaExceeded
    nextStatus = 200;
    nextBody = jsonEncode({'pad': 'a' * (4 * 1024 * 1024 + 100)});
    await expectLater(
      direct.get('/movie/6', {}),
      throwsA(isA<PluginException>().having((e) => e.code, 'code', 'quotaExceeded')),
    );

    // Closed transport -> cancelled
    direct.close();
    platform.close();
    await expectLater(
      direct.get('/movie/7', {}),
      throwsA(isA<PluginException>().having((e) => e.code, 'code', 'cancelled')),
    );
  });
}
