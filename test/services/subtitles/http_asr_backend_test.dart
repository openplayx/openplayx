// Part 1 runs against a local fake server. Part 2 needs a real
// openplayx-asr (OPX_ASR_TEST_URL, OPX_ASR_TEST_TOKEN) plus the host FFmpeg
// bridge; skipped otherwise.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/core/plugins/speech_recognition_capability.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/services/media_processing/media_processing_service.dart';
import 'package:openplayx/services/subtitles/asr_backend_config.dart';
import 'package:openplayx/services/subtitles/asr_model_store.dart';
import 'package:openplayx/services/subtitles/http_asr_backend.dart';
import 'package:openplayx/services/subtitles/subtitle_generation_service.dart';
import 'package:openplayx_ffmpeg/openplayx_ffmpeg.dart';
import 'package:sqlite3/sqlite3.dart';

class _Sources extends SourceManager {
  @override
  Future<void> load() async {}
}

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
  final wav = File('../whisper-package/test/fixtures/en.wav').absolute;
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
              'jobs': created ? [job] : [],
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

  group('live openplayx-asr', () {
    final url = Platform.environment['OPX_ASR_TEST_URL'];
    final token = Platform.environment['OPX_ASR_TEST_TOKEN'];
    final ext = Platform.isMacOS ? 'dylib' : 'so';
    final ffmpeg = File('../ffmpeg-package/build/host/libopenplayx_ffmpeg.$ext')
        .absolute
        .path;
    final skip = url == null || token == null
        ? 'set OPX_ASR_TEST_URL/TOKEN'
        : null;

    test('direct: upload, recognise, remote cleanup', () async {
      final b = HttpAsrBackend(config: _config(url!), token: () async => token);
      final stages = <AsrStage>[];
      final r = await b.transcribe(request, _ctx(null, stages));
      expect(stages, contains(AsrStage.uploading));
      expect(
        r.raw.windows
            .expand((w) => w.segments)
            .map((s) => s.text)
            .join()
            .toLowerCase(),
        contains('fox'),
      );
      expect(r.modelRevision, '60ed5bc3dd14');
      expect(await b.deleteRemote(r.remoteJobId!), isTrue);
    }, skip: skip);

    test('cancel while running stops the remote job', () async {
      final long = File('../whisper-package/test/fixtures/long.wav').absolute;
      final b = HttpAsrBackend(
        config: _config(url!),
        token: () async => token,
        pollMin: const Duration(milliseconds: 100),
      );
      final cancel = AsrCancelToken();
      String? remote;
      final future = b.transcribe(
        TranscriptionRequest(
          audioPath: long.path,
          audioMs: 49651,
          audioSha256: '${sha256.convert(long.readAsBytesSync())}',
          language: 'en',
        ),
        AsrTaskContext(
          cancel: cancel,
          report: (s, {processedMs, totalMs}) {
            if (s == AsrStage.transcribing || s == AsrStage.queued)
              cancel.cancel();
          },
          remoteJob: (id) => remote = id,
        ),
      );
      await expectLater(
        future,
        throwsA(
          isA<AsrBackendException>().having((e) => e.code, 'code', 'cancelled'),
        ),
      );
      // The service reaches cancelled; deletion then succeeds.
      var deleted = false;
      for (var i = 0; i < 50 && !deleted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        deleted = await b.deleteRemote(remote!);
      }
      expect(deleted, isTrue);
    }, skip: skip);

    test(
      'workflow: FFmpeg extract → HTTP service → media-time subtitles',
      () async {
        if (!File(ffmpeg).existsSync()) return;
        final tmp = Directory.systemTemp.createTempSync('opx_http_flow');
        final library = LibraryService(sqlite3.openInMemory());
        final media = MediaProcessingService(
          db: library.db,
          sources: _Sources(),
          root: Future.value(Directory('${tmp.path}/media')),
          processor: MediaProcessor(
            libraryPath: ffmpeg,
            pollInterval: const Duration(milliseconds: 20),
          ),
        );
        final registry = AsrBackendRegistry(
          db: library.configuration,
          models: AsrModelStore(Future.value(null)),
          readCredential: (_) async => token,
        );
        registry.save(_config(url!));
        registry.grantUploadConsent('svc');
        final service = SubtitleGenerationService(
          db: library.db,
          media: media,
          backends: registry,
          root: Future.value(Directory('${tmp.path}/subtitles')),
        );
        try {
          final input = File('../whisper-package/test/fixtures/long.wav')
              .absolute
              .path;
          final run = service.start(
            SubtitleRequest(
              resource: ResourceRef('@local', input),
              resourceName: 'long.wav',
              caller: SubtitleCaller.ai,
              startMs: 36000,
              endMs: 49000,
              backendId: 'svc',
              language: 'en',
            ),
          );
          final stages = <AsrStage>{};
          run.updates.listen((s) => stages.add(s.stage));
          final s = await run.done;
          expect(s.status, SubtitleRunStatus.succeeded, reason: s.error);
          expect(
            stages,
            containsAll([
              AsrStage.extracting,
              AsrStage.uploading,
              AsrStage.formatting,
            ]),
          );
          expect(s.transcript!.backend, 'http');
          expect(
            s.transcript!.segments.first.startMs,
            inInclusiveRange(40300, 41700),
          );
          final task = service.task(run.taskId)!;
          expect(task['subtitle_artifact_ref'], isNotNull);
          // Remote input/output were deleted after the app stored the result.
          for (var i = 0; i < 20; i++) {
            final r = library.db.select(
              'SELECT remote_cleanup FROM transcription_tasks WHERE id=?',
              [run.taskId],
            ).first;
            if (r['remote_cleanup'] != null) break;
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          expect(
            library.db.select(
              'SELECT remote_cleanup FROM transcription_tasks WHERE id=?',
              [run.taskId],
            ).first['remote_cleanup'],
            'done',
          );
        } finally {
          service.dispose();
          media.dispose();
          library.close();
          tmp.deleteSync(recursive: true);
        }
      },
      skip: skip,
    );
  });
}
