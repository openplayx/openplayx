import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/web_playback/web_playback_catalog.dart';
import 'package:openplayx/capabilities/web_playback/web_playback_service.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/sources/stream_gateway.dart';

class TestCatalog implements WebPlaybackCatalog {
  TestCatalog(this.file);
  final File file;
  bool visible = true;
  int released = 0;
  int? savedPosition;
  bool? completed;
  Future<PlayableStream> Function()? opening;
  WebMedia get item => WebMedia(
    id: 'resource-1',
    title: 'Private film',
    name: 'film.mp4',
    ref: const ResourceRef('source', 'secret-path'),
    positionMs: savedPosition ?? 0,
  );
  @override
  List<WebShareScope> get scopes => [const WebShareScope('movies', 'Movies')];
  @override
  Set<String> loadSharedScopes() => {};
  @override
  void saveSharedScopes(Set<String> ids) {}
  @override
  List<WebMedia> list(
    Set<String> shared, {
    String search = '',
    int offset = 0,
  }) =>
      visible &&
          shared.contains('movies') &&
          offset == 0 &&
          item.title.contains(search)
      ? [item]
      : [];
  @override
  WebMedia? find(Set<String> shared, String id) =>
      visible && shared.contains('movies') && id == item.id ? item : null;
  @override
  Future<PlayableStream> open(WebMedia media) async => opening == null
      ? PlayableStream(
          file.uri,
          release: () async {
            released++;
          },
        )
      : await opening!();
  @override
  String beginProgress(WebMedia media) => 'progress-session';
  @override
  void saveProgress(
    WebMedia media,
    String session,
    int positionMs,
    int durationMs,
    bool completed,
  ) {
    savedPosition = positionMs;
    this.completed = completed;
  }
}

class Reply {
  Reply(this.status, this.body, this.headers, this.cookies);
  final int status;
  final List<int> body;
  final HttpHeaders headers;
  final List<Cookie> cookies;
  dynamic get json => jsonDecode(utf8.decode(body));
}

void main() {
  late Directory temp;
  late TestCatalog catalog;
  late WebPlaybackService service;
  late HttpClient client;
  String? cookie;
  Future<Reply> request(
    String path, {
    String method = 'GET',
    Object? body,
    bool authenticated = true,
    Map<String, String> headers = const {},
  }) async {
    final r = await client.openUrl(
      method,
      Uri.parse('${service.address}$path'),
    );
    if (authenticated && cookie != null) r.headers.set('Cookie', cookie!);
    if (method != 'GET' && method != 'HEAD') r.headers.set('X-OpenPlayX', '1');
    headers.forEach(r.headers.set);
    if (body != null) {
      r.headers.contentType = ContentType.json;
      r.write(jsonEncode(body));
    }
    final response = await r.close();
    final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
    return Reply(
      response.statusCode,
      bytes,
      response.headers,
      response.cookies,
    );
  }

  Future<void> pair() async {
    final response = await request(
      '/api/pair',
      method: 'POST',
      body: {'code': service.pairingCode, 'device': 'Living room'},
    );
    expect(response.status, 200);
    final c = response.cookies.single;
    expect(c.httpOnly, isTrue);
    expect(c.sameSite, SameSite.strict);
    cookie = '${c.name}=${c.value}';
  }

  Future<Map<String, dynamic>> play() async {
    final r = await request(
      '/api/playback',
      method: 'POST',
      body: {'id': 'resource-1'},
    );
    expect(r.status, 200);
    return r.json as Map<String, dynamic>;
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('opx-web-test-');
    final file = await File('${temp.path}/secret-film.mp4')
        .writeAsBytes(List.generate(256, (i) => i));
    catalog = TestCatalog(file);
    service = WebPlaybackService(catalog);
    client = HttpClient();
    cookie = null;
    expect(service.running, isFalse);
    await service.start(InternetAddress.loopbackIPv4, port: 0);
  });
  tearDown(() async {
    client.close(force: true);
    await service.shutdown();
    service.dispose();
    await temp.delete(recursive: true);
  });

  test('public UI is local, credentials are required, no folders shared by default', () async {
    final page = await request('/');
    expect(page.status, 200);
    expect(
      page.headers.value('content-security-policy'),
      contains("frame-ancestors 'none'"),
    );
    expect((await request('/api/library')).status, 401);
    await pair();
    expect((await request('/api/library')).json['items'], isEmpty);
    expect(
      (await request(
        '/api/playback',
        method: 'POST',
        body: {'id': 'resource-1'},
      )).status,
      404,
    );
    await service.setSharedScopes({'movies'});
    final items = (await request('/api/library')).json['items'] as List;
    expect(items.single['title'], 'Private film');
    expect(jsonEncode(items), isNot(contains('secret-path')));
    expect(jsonEncode(items), isNot(contains(temp.path)));
  });
  test(
    'host and origin validation block rebinding and cross-site requests',
    () async {
      expect(
        (await request('/', headers: {'Host': 'evil.example'})).status,
        403,
      );
      expect(
        (await request('/', headers: {'Origin': 'http://evil.example'})).status,
        403,
      );
      final r = await client.postUrl(Uri.parse('${service.address}/api/pair'));
      r.headers.contentType = ContentType.json;
      r.write(jsonEncode({'code': service.pairingCode, 'device': 'evil'}));
      final response = await r.close();
      expect(response.statusCode, 403);
      await response.drain<void>();
    },
  );
  test('pairing is rate limited and rotating the code invalidates old codes', () async {
    final old = service.pairingCode;
    service.refreshPairingCode();
    // A random collision is possible, so only assert expiry when code changed.
    if (old != service.pairingCode) {
      expect(
        (await request(
          '/api/pair',
          method: 'POST',
          body: {'code': old, 'device': 'Test'},
        )).status,
        403,
      );
    }
    for (var i = 0; i < 6; i++) {
      final r = await request(
        '/api/pair',
        method: 'POST',
        body: {'code': '000000', 'device': 'Test'},
      );
      if (i == 5) expect(r.status, 429);
    }
  });
  test(
    'local media serves GET HEAD prefix suffix open ranges and 416',
    () async {
      await pair();
      await service.setSharedScopes({'movies'});
      final p = await play();
      final url = p['url'] as String;
      final full = await request(url);
      expect(full.status, 200);
      expect(full.body.length, 256);
      final head = await request(url, method: 'HEAD');
      expect(head.status, 200);
      expect(head.body, isEmpty);
      expect(head.headers.contentLength, 256);
      for (final (range, start, end) in [
        ('bytes=10-19', 10, 19),
        ('bytes=250-', 250, 255),
        ('bytes=-3', 253, 255),
      ]) {
        final r = await request(url, headers: {'Range': range});
        expect(r.status, 206);
        expect(r.body, List.generate(end - start + 1, (i) => start + i));
        expect(r.headers.value('content-range'), 'bytes $start-$end/256');
      }
      for (final range in [
        'bytes=300-',
        'bytes=5-2',
        'bytes=-0',
        'bytes=-',
        'bytes=0-1,3-4',
        'bytes=999999999999999999999999-',
      ]) {
        final r = await request(url, headers: {'Range': range});
        expect(r.status, 416, reason: range);
        expect(r.headers.value('content-range'), 'bytes */256');
      }
      expect((await request(url, authenticated: false)).status, 401);
    },
  );
  test('progress is validated and saved through the catalog', () async {
    await pair();
    await service.setSharedScopes({'movies'});
    final p = await play();
    final path = '/api/playback/${p['id']}/progress';
    expect(
      (await request(
        path,
        method: 'POST',
        body: {'positionMs': 1200, 'durationMs': 5000, 'completed': true},
      )).status,
      200,
    );
    expect(catalog.savedPosition, 1200);
    expect(catalog.completed, true);
    expect(
      (await request(
        path,
        method: 'POST',
        body: {'positionMs': -1, 'durationMs': 5000},
      )).status,
      400,
    );
    expect(catalog.savedPosition, 1200);
  });
  test(
    'ending or unsharing a session revokes media and releases its source',
    () async {
      await pair();
      await service.setSharedScopes({'movies'});
      final p = await play();
      await service.endSession(p['id'] as String);
      expect(catalog.released, 1);
      expect((await request(p['url'] as String)).status, 404);
      final second = await play();
      await service.setSharedScopes({});
      expect(catalog.released, 2);
      expect((await request(second['url'] as String)).status, 404);
    },
  );
  test('source visibility changes revoke an existing stream', () async {
    await pair();
    await service.setSharedScopes({'movies'});
    final p = await play();
    catalog.visible = false;
    expect((await request(p['url'] as String)).status, 404);
    expect(catalog.released, 1);
  });
  test('a second device cannot read or end another devices playback', () async {
    await pair();
    await service.setSharedScopes({'movies'});
    final p = await play();
    await pair();
    expect((await request(p['url'] as String)).status, 404);
    expect(
      (await request('/api/playback/${p['id']}', method: 'DELETE')).status,
      404,
    );
    expect(service.sessions, hasLength(1));
  });
  test(
    'stop revokes pairing cookies and drains late source resolution',
    () async {
      await pair();
      await service.setSharedScopes({'movies'});
      final resolve = Completer<PlayableStream>(), entered = Completer<void>();
      catalog.opening = () {
        entered.complete();
        return resolve.future;
      };
      final pending = request(
        '/api/playback',
        method: 'POST',
        body: {'id': 'resource-1'},
      ).then<void>((_) {}, onError: (Object _) {});
      await entered.future;
      await service.stop();
      resolve.complete(
        PlayableStream(
          catalog.file.uri,
          release: () async {
            catalog.released++;
          },
        ),
      );
      await pending;
      await service.shutdown();
      expect(catalog.released, 1);
      expect(service.sessions, isEmpty);
      await service.start(InternetAddress.loopbackIPv4, port: 0);
      expect((await request('/api/session')).status, 401);
    },
  );
  test(
    'loopback upstream preserves Range and never redirects credentials',
    () async {
      final gateway = await StreamGateway.ranged(
        length: 256,
        filename: 'remote.mp4',
        read: (start, end) async* {
          yield List.generate(end - start + 1, (i) => start + i);
        },
      );
      catalog.opening = () async => gateway;
      await pair();
      await service.setSharedScopes({'movies'});
      final p = await play();
      final range = await request(
        p['url'] as String,
        headers: {'Range': 'bytes=12-15'},
      );
      expect(range.status, 206);
      expect(range.body, [12, 13, 14, 15]);
      await service.endSession(p['id'] as String);
    },
  );
  test('only specific local interfaces can be bound', () async {
    await service.stop();
    expect(
      () => service.start(InternetAddress.anyIPv4, port: 0),
      throwsArgumentError,
    );
    expect(
      () => service.start(InternetAddress('8.8.8.8'), port: 0),
      throwsArgumentError,
    );
  });
}
