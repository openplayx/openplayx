import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/capabilities/speech_recognition_capability.dart';
import 'package:openplayx/capabilities/speech/asr_backend_config.dart';
import 'package:openplayx/capabilities/speech/asr_model_store.dart';
import 'package:openplayx/capabilities/speech/openai_asr_backend.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('platform is the default, preferences persist and built-ins cannot be removed', () async {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    AsrBackendRegistry registry() =>
        AsrBackendRegistry(db: db, models: AsrModelStore(Future.value(null)));
    final r = registry();
    expect(r.defaultBackendId, 'platform');
    expect(r.list().first.modelId, 'whisper-large-v3');
    r.selectDefault('embedded');
    expect(registry().defaultBackendId, 'embedded');
    await r.remove('platform');
    expect(r.get('platform'), isNotNull);
  });

  late HttpServer server;
  late Directory tmp;
  late TranscriptionRequest input;
  setUp(() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    tmp = await Directory.systemTemp.createTemp('opx_openai_asr');
    final audio = await File('../package-whisper/test/fixtures/en.wav')
        .copy('${tmp.path}/input.wav');
    input = TranscriptionRequest(
      audioPath: audio.path,
      audioMs: 5651,
      audioSha256: 'test',
      language: 'en',
    );
  });
  tearDown(() async {
    await server.close(force: true);
    await tmp.delete(recursive: true);
  });
  OpenAiAsrBackend backend({bool platform = true}) => OpenAiAsrBackend(
    config: AsrBackendConfig(
      id: 'test',
      kind: platform ? 'platform' : 'http',
      name: 'test',
      url:
          'http://127.0.0.1:${server.port}${platform ? '/v1/subtitles/transcriptions' : '/v1'}',
      modelId: 'whisper-large-v3',
      protocol: 'openai',
      uploadConsentAt: DateTime.now(),
    ),
    token: () async => platform ? null : 'own-key',
  );
  AsrTaskContext context([AsrCancelToken? cancel]) => AsrTaskContext(
    cancel: cancel ?? AsrCancelToken(),
    report: (_, {processedMs, totalMs}) {},
  );

  test(
    'platform streams multipart without a client key and converts seconds once',
    () async {
      server.listen((r) async {
        expect(r.uri.path, '/v1/subtitles/transcriptions');
        expect(r.headers.value('Authorization'), isNull);
        final bytes = await r.fold<List<int>>([], (a, b) => a..addAll(b));
        final body = utf8.decode(bytes, allowMalformed: true);
        expect(body, contains('whisper-large-v3'));
        expect(body, contains('verbose_json'));
        expect(body, contains('filename="audio.wav"'));
        r.response.headers.contentType = ContentType.json;
        r.response.write(
          jsonEncode({
            'text': 'hello',
            'language': 'en',
            'segments': [
              {'start': 1.25, 'end': 2.75, 'text': 'hello'},
            ],
          }),
        );
        await r.response.close();
      });
      final result = await backend().transcribe(input, context());
      final s = result.raw.windows.single.segments.single;
      expect(s.startMs, 1250);
      expect(s.endMs, 2750);
    },
  );
  test('custom OpenAI API uses its own key and endpoint', () async {
    server.listen((r) async {
      expect(r.uri.path, '/v1/audio/transcriptions');
      expect(r.headers.value('Authorization'), 'Bearer own-key');
      await r.drain<void>();
      r.response.write(jsonEncode({'text': '', 'segments': []}));
      await r.response.close();
    });
    expect(
      (await backend(
        platform: false,
      ).transcribe(input, context())).raw.windows.single.segments,
      isEmpty,
    );
  });
  test(
    'invalid timestamps fail instead of producing misleading subtitles',
    () async {
      server.listen((r) async {
        await r.drain<void>();
        r.response.write(
          jsonEncode({
            'text': 'hello',
            'segments': [
              {'start': 3, 'end': 1, 'text': 'hello'},
            ],
          }),
        );
        await r.response.close();
      });
      await expectLater(
        backend().transcribe(input, context()),
        throwsA(
          isA<AsrBackendException>().having(
            (e) => e.code,
            'code',
            'result_invalid',
          ),
        ),
      );
    },
  );
  test('cancel interrupts rate-limit waiting without starting another paid request', () async {
    final cancel = AsrCancelToken();
    var calls = 0;
    server.listen((r) async {
      calls++;
      await r.drain<void>();
      r.response.statusCode = 429;
      r.response.headers.set('Retry-After', '60');
      await r.response.close();
      Timer(const Duration(milliseconds: 20), cancel.cancel);
    });
    await expectLater(
      backend().transcribe(input, context(cancel)),
      throwsA(
        isA<AsrBackendException>().having((e) => e.code, 'code', 'cancelled'),
      ),
    );
    expect(calls, 1);
  });
}
