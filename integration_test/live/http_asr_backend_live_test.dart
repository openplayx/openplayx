// Live integration tests against a real openplayx-asr server
// (OPX_ASR_TEST_URL, OPX_ASR_TEST_TOKEN) plus the host FFmpeg bridge;
// skipped otherwise.
// Run: flutter test integration_test/live/http_asr_backend_live_test.dart
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/media_processing/media_processing_service.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/capabilities/speech/asr_backend_config.dart';
import 'package:openplayx/capabilities/speech/asr_model_store.dart';
import 'package:openplayx/capabilities/speech/http_asr_backend.dart';
import 'package:openplayx/capabilities/speech/subtitle_generation_service.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/core/capabilities/speech_recognition_capability.dart';
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
  final wav = File('../package-whisper/test/fixtures/en.wav').absolute;
  final sha = sha256.convert(wav.readAsBytesSync()).toString();
  final request = TranscriptionRequest(
    audioPath: wav.path,
    audioMs: 5651,
    audioSha256: sha,
    language: 'en',
  );

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
      final long = File('../package-whisper/test/fixtures/long.wav').absolute;
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
            if (s == AsrStage.transcribing || s == AsrStage.queued) {
              cancel.cancel();
            }
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
          final input = File('../package-whisper/test/fixtures/long.wav')
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
