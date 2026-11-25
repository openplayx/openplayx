import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/sources/media_server_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';

void main() {
  late HttpServer server;
  late JellyfinPlugin plugin;
  late List<Map<String, dynamic>> negotiations;
  late List<String> stopped;
  late String transcodingUrl;
  late int bytesRequested;
  setUp(() async {
    negotiations = [];
    stopped = [];
    bytesRequested = 0;
    transcodingUrl = '/base/Videos/movie/stream.ts?VideoCodec=copy&AudioCodec=copy&ApiKey=secret';
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    plugin = JellyfinPlugin(
      SourceConfig(
        id: 'jf',
        kind: SourceKind.jellyfin,
        name: 'Test',
        address: 'http://127.0.0.1:${server.port}/base',
        userId: 'user',
      ),
      SourceHttp(
        SourceConfig(
          id: 'jf',
          kind: SourceKind.jellyfin,
          name: 'Test',
          address: 'http://127.0.0.1:${server.port}/base',
          userId: 'user',
        ),
        'secret',
      ),
    );
    server.listen((r) async {
      expect(r.headers.value('authorization'), contains('Token="secret"'));
      r.response.headers.contentType = ContentType.json;
      Object? response;
      switch (r.uri.path) {
        case '/base/Users/user/Items/movie':
          response = {
            'MediaType': 'Video',
            'MediaSources': [
              {'Id': 'source'},
            ],
          };
        case '/base/Items/movie/PlaybackInfo':
          final body = jsonDecode(
            await utf8.decoder.bind(r).join(),
          ) as Map<String, dynamic>;
          negotiations.add(body);
          response = {
            'PlaySessionId': 'session-${negotiations.length}',
            'MediaSources': [
              {
                'Id': 'source',
                'Container': 'mp4',
                'SupportsDirectPlay': body['EnableDirectPlay'],
                'SupportsTranscoding': true,
                'TranscodingSubProtocol': 'http',
                'TranscodingUrl': transcodingUrl,
                'MediaStreams': [
                  {'Type': 'Audio'},
                ],
              },
            ],
          };
        case '/base/Sessions/Playing':
          await r.drain<void>();
          r.response.statusCode = 204;
        case '/base/Sessions/Playing/Stopped':
          final body = jsonDecode(await utf8.decoder.bind(r).join());
          stopped.add(body['PlaySessionId'] as String);
          r.response.statusCode = 204;
        case '/base/Videos/movie/stream':
        case '/base/Videos/movie/stream.ts':
          bytesRequested++;
          expect(
            r.uri.queryParameters.keys.any((k) => k.toLowerCase() == 'apikey'),
            isFalse,
          );
          expect(r.headers.value('range'), 'bytes=1-2');
          r.response.statusCode = 206;
          r.response.headers.set('content-range', 'bytes 1-2/4');
          r.response.add([2, 3]);
        default:
          r.response.statusCode = 404;
      }
      if (response != null) r.response.write(jsonEncode(response));
      await r.response.close();
    });
  });
  tearDown(() async {
    await plugin.dispose();
    await server.close(force: true);
  });
  Future<PlayableStream> resolve() => plugin.resolve(
    const ResolveRequest(ResourceRef('jf', 'movie')),
    CallContext.forInstance('jf'),
  );
  test('negotiates direct play, retries remux only once and releases both sessions', () async {
    final direct = await resolve();
    expect(direct.playbackMethod, 'DirectPlay');
    final remux = (await direct.retry())!;
    expect(remux.playbackMethod, 'Remux');
    expect(await direct.retry(), isNull);
    expect(remux.fallback, isNull);
    expect(negotiations.map((n) => n['EnableDirectPlay']), [true, false]);
    for (final stream in [direct, remux]) {
      expect(stream.uri.host, '127.0.0.1');
      expect(stream.uri.toString(), isNot(contains('secret')));
      final c = HttpClient();
      final r = await c.getUrl(stream.uri);
      r.headers.set('Range', 'bytes=1-2');
      final response = await r.close();
      expect(response.statusCode, 206);
      expect(await response.fold<List<int>>([], (a, b) => a..addAll(b)), [
        2,
        3,
      ]);
      c.close(force: true);
      await stream.release();
      await stream.release();
    }
    expect(stopped, ['session-1', 'session-2']);
    expect(bytesRequested, 2);
  });
  test(
    'rejects foreign origin before credentials or media requests escape',
    () async {
      transcodingUrl = 'https://foreign.invalid/file.ts?ApiKey=secret';
      final direct = await resolve();
      await expectLater(
        direct.retry(),
        throwsA(
          isA<PluginException>().having(
            (e) => e.code,
            'code',
            'permissionDenied',
          ),
        ),
      );
      expect(bytesRequested, 0);
      expect(stopped, ['session-2']);
      await direct.release();
    },
  );
  test(
    'release cancels retry and source disposal releases outstanding sessions',
    () async {
      final first = await resolve();
      await first.release();
      expect(await first.retry(), isNull);
      await resolve();
      await plugin.dispose();
      expect(stopped, ['session-1', 'session-2']);
    },
  );
}
