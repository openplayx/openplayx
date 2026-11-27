import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/speech/asr_model_store.dart';
import 'package:openplayx/data/analytics/analytics_service.dart';

void main() {
  group('AsrModelStore', () {
    late Directory tmp;
    late AsrModelStore store;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('opx_model_store_');
      store = AsrModelStore(Future.value(tmp));
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test('catalog metadata and empty store state', () async {
      final tiny = asrModelSpec('whisper-tiny-multilingual')!;
      expect(tiny.multilingual, isTrue);
      expect(tiny.license, contains('MIT'));
      expect(tiny.revision, hasLength(12));
      expect(tiny.url.scheme, 'https');
      expect(asrModelSpec('unknown-id'), isNull);

      expect(await store.installed(), isEmpty);
      expect(await store.path(tiny.id), isNull);
      expect(store.activeDownload(tiny.id), isNull);
    });

    test('import rejects unknown size and bad checksum, remove cleans up', () async {
      final badSize = File('${tmp.path}/small.bin')..writeAsBytesSync([1, 2, 3]);
      await expectLater(
        store.import(badSize),
        throwsA(isA<FormatException>()),
      );

      // Write a fake installed entry in manifest + file to test installed(), path(), remove().
      final tiny = asrModelSpec('whisper-tiny-multilingual')!;
      File('${tmp.path}/${tiny.file}').writeAsBytesSync([0, 1, 2]);
      File('${tmp.path}/models.json').writeAsStringSync(
        '{"${tiny.id}":{"file":"${tiny.file}","sha256":"${tiny.sha256}","bytes":${tiny.bytes}}}',
      );
      expect(await store.installed(), contains(tiny.id));
      expect(await store.path(tiny.id), '${tmp.path}/${tiny.file}');

      await store.remove(tiny.id);
      expect(await store.installed(), isEmpty);
      expect(File('${tmp.path}/${tiny.file}').existsSync(), isFalse);
      // Removing unknown id is a no-op.
      await store.remove('nonexistent');
    });

    test('download handles unknown id, HTTP failure and cancel', () async {
      expect(() => store.download('nope'), throwsArgumentError);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((req) async {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      });

      final failingStore = AsrModelStore(
        Future.value(tmp),
        client: () => _RedirectClient(server.port),
      );
      final dl = failingStore.download('whisper-tiny-multilingual');
      expect(failingStore.activeDownload('whisper-tiny-multilingual'), same(dl));
      await expectLater(dl.done, throwsA(isA<HttpException>()));
      expect(failingStore.activeDownload('whisper-tiny-multilingual'), isNull);
    });

    test('download can be cancelled before completion', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((req) async {
        req.response.statusCode = HttpStatus.ok;
        req.response.headers.contentLength = 1024 * 1024;
        for (var i = 0; i < 20; i++) {
          try {
            req.response.add(List.filled(1024, 7));
            await req.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 20));
          } catch (_) {
            break;
          }
        }
        try {
          await req.response.close();
        } catch (_) {}
      });

      final cancelStore = AsrModelStore(
        Future.value(tmp),
        client: () => _RedirectClient(server.port),
      );
      final dl = cancelStore.download('whisper-tiny-multilingual');
      dl.progress.listen((_) => dl.cancel());
      await expectLater(dl.done, throwsA(isA<AsrModelCancelled>()));
    });
  });

  group('AnalyticsService', () {
    testWidgets('sanitize, forwardTo, screen, interaction and lifecycle', (
      tester,
    ) async {
      final sent = <(String, Map<String, Object>)>[];
      final svc = AnalyticsService.instance;
      svc.forwardTo((event, props) async {
        sent.add((event, props));
      });
      addTearDown(() async {
        await svc.close();
      });

      final safe = AnalyticsService.sanitize({
        'source_type': 'smb',
        'status': 'success',
        'duration_ms': 1200,
        'screen_name': 'home',
        'success': true,
        'secret_token': 'drop-me',
        'bad_num': double.infinity,
        'bad_label': 'spaces not allowed!',
      });
      expect(safe.keys, containsAll(['source_type', 'status', 'duration_ms', 'screen_name', 'success']));
      expect(safe.containsKey('secret_token'), isFalse);
      expect(safe.containsKey('bad_num'), isFalse);
      expect(safe.containsKey('bad_label'), isFalse);

      await svc.screen('settings');
      await svc.screen('bad screen name!'); // ignored
      svc.interaction(const Offset(100, 200));
      await svc.capture('playback_started', {'source_type': 'local'});
      await svc.capture('not_an_allowed_event', {'source_type': 'local'});
      await tester.pump();

      expect(sent.any((e) => e.$1 == r'$screen'), isTrue);
      expect(sent.any((e) => e.$1 == 'ui_interaction'), isTrue);
      expect(sent.any((e) => e.$1 == 'playback_started'), isTrue);
      expect(sent.any((e) => e.$1 == 'not_an_allowed_event'), isFalse);

      // Lifecycle hooks are safe when not owning SDK.
      svc.didChangeAppLifecycleState(AppLifecycleState.paused);
      svc.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(svc.ownsSdk, isFalse);
    });
  });
}

class _RealHttp extends HttpOverrides {}

class _RedirectClient implements HttpClient {
  _RedirectClient(this.port)
    : _inner = HttpOverrides.runWithHttpOverrides(HttpClient.new, _RealHttp());
  final int port;
  final HttpClient _inner;

  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      _inner.getUrl(Uri.parse('http://127.0.0.1:$port${url.path}'));

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
