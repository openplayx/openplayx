// Unit tests against a local fake HTTP ASR server.
// Live openplayx-asr integration tests live in
// integration_test/live/http_asr_backend_live_test.dart.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/capabilities/speech_recognition_capability.dart';
import 'package:openplayx/capabilities/speech/asr_backend_config.dart';
import 'package:openplayx/capabilities/speech/asr_model_store.dart';
import 'package:openplayx/capabilities/speech/http_asr_backend.dart';
import 'package:sqlite3/sqlite3.dart';

AsrBackendConfig _config(String url) => AsrBackendConfig(
  id: 'svc',
  kind: 'http',
  name: 'svc',
  url: url,
  modelId: 'whisper-base-multilingual',
  allowInsecureHttp: true,
);

AsrTaskContext _ctx([AsrCancelToken? cancel, List<AsrStage>? stages]) =>
    AsrTaskContext(
      cancel: cancel ?? AsrCancelToken(),
      report: (s, {processedMs, totalMs}) => stages?.add(s),
    );

void main() {
  final wav = File('../package-whisper/test/fixtures/en.wav').absolute;
  final sha = sha256.convert(wav.readAsBytesSync()).toString();
  final request = TranscriptionRequest(
    audioPath: wav.path,
    audioMs: 5651,
    audioSha256: sha,
    language: 'en',
  );

  group('fake server', () {
    late HttpServer server;
    late List<String> log;
    var dropFirstCreate = false;
    var created = false;
    setUp(() async {
      log = [];
      created = false;
      server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((r) async {
        log.add('${r.method} ${r.uri.path}');
        Future<void> json(int status, Object body) async {
          r.response.statusCode = status;
          r.response.headers.contentType = ContentType.json;
          r.response.write(jsonEncode(body));
          await r.response.close();
        }

        if (r.headers.value('authorization') != 'Bearer good') {
          return json(401, {
            'error': {'code': 'unauthorized'},
          });
        }
        final job = {'id': 'job_1', 'status': 'succeeded', 'audio_ms': 5651};
        switch ((r.method, r.uri.path)) {
          case ('GET', '/v1/capabilities'):
            return json(200, {
              'engine': 'whisper.cpp',
              'engine_version': 't',
              'models': [
                {'id': 'whisper-base-multilingual', 'revision': 'abc'},
              ],
              'limits': {'max_upload_bytes': 1 << 30, 'max_audio_ms': 1 << 30},
            });
          case ('GET', '/v1/transcription-jobs'):
            return json(200, {
              'jobs': created ? [job] : <Object?>[],
            });
          case ('POST', '/v1/transcription-jobs'):
            expect(r.headers.value('x-content-sha256'), sha);
            expect(r.uri.queryParameters.containsKey('translate'), isFalse);
            await r.drain<void>();
            created = true;
            if (dropFirstCreate) {
              dropFirstCreate = false;
              // Job accepted but the response is lost.
              await r.response.detachSocket().then((s) => s.destroy());
              return;
            }
            return json(202, job);
          case ('GET', '/v1/transcription-jobs/job_1/result'):
            return json(200, {
              'timebase': 'audio_ms',
              'language': 'en',
              'audio_ms': 5651,
              'window_ms': 30000,
              'overlap_ms': 1000,
              'model_id': 'whisper-base-multilingual',
              'model_revision': 'abc',
              'windows': [
                {
                  'offset_ms': 0,
                  'duration_ms': 5651,
                  'segments': [
                    {'start_ms': 0, 'end_ms': 5000, 'text': 'hello'},
                  ],
                },
              ],
            });
          case ('DELETE', '/v1/transcription-jobs/job_1'):
            r.response.statusCode = 204;
            return r.response.close();
        }
        return json(404, {
          'error': {'code': 'not_found'},
        });
      });
    });
    tearDown(() => server.close(force: true));

    HttpAsrBackend backend(String token) => HttpAsrBackend(
      config: _config('http://127.0.0.1:${server.port}'),
      token: () async => token,
      pollMin: const Duration(milliseconds: 10),
    );

    test('bad credentials are reported as unauthorized', () async {
      final s = await backend('bad').status();
      expect(s.available, isFalse);
      expect(s.reason, 'backend_unauthorized');
    });

    test('lost create response is reconciled by idempotency key', () async {
      dropFirstCreate = true;
      final b = backend('good');
      final result = await b.transcribe(request, _ctx());
      expect(result.raw.windows.single.segments.single.text, 'hello');
      expect(result.remoteJobId, 'job_1');
      // Exactly one upload reached the service.
      expect(
        log.where((l) => l == 'POST /v1/transcription-jobs'),
        hasLength(1),
      );
    });

    test('unreachable service is a retryable short code', () async {
      final b = HttpAsrBackend(
        config: _config('http://127.0.0.1:1'),
        token: () async => 'good',
      );
      final s = await b.status();
      expect(s.reason, 'backend_unreachable');
    });

    test('URLs with credentials or plain http without opt-in are refused', () {
      final db = sqlite3.openInMemory();
      final reg = AsrBackendRegistry(
        db: db,
        models: AsrModelStore(Future.value(null)),
        readCredential: (_) async => null,
      );
      expect(
        () => reg.save(_config('https://user:pw@host')),
        throwsFormatException,
      );
      expect(
        () => reg.save(
          AsrBackendConfig(
            id: 'x',
            kind: 'http',
            name: 'x',
            url: 'http://lan:8787',
            modelId: 'm',
          ),
        ),
        throwsFormatException,
      );
      final saved = reg.save(_config('https://asr.lan'));
      reg.grantUploadConsent(saved.id);
      expect(reg.get(saved.id)!.uploadConsentAt, isNotNull);
      // Consent names one destination: a new URL drops it.
      reg.save(reg.get(saved.id)!.copyWith(url: 'https://other.lan'));
      expect(reg.get(saved.id)!.uploadConsentAt, isNull);
      db.close();
    });
  });
}
