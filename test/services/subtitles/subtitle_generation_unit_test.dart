import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/media_processing/media_processing_service.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/capabilities/speech/asr_backend_config.dart';
import 'package:openplayx/capabilities/speech/asr_model_store.dart';
import 'package:openplayx/capabilities/speech/subtitle_format.dart';
import 'package:openplayx/capabilities/speech/subtitle_generation_service.dart';
import 'package:openplayx/capabilities/speech/transcript.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx_whisper/openplayx_whisper.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../support/fake_media_processor.dart';

class _NoSources extends SourceManager {
  @override
  Future<void> load() async {}
}

void main() {
  late Directory tmp;
  late File sampleFile;
  late LibraryService library;
  late FakeMediaProcessor processor;
  late MediaProcessingService media;
  late FakeAsrBackend fakeBackend;
  late AsrBackendRegistry registry;
  late SubtitleGenerationService service;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('opx_sub_unit_');
    sampleFile = File('${tmp.path}/episode.mp4')..writeAsBytesSync([1, 2, 3]);
    library = LibraryService(sqlite3.openInMemory());
    processor = FakeMediaProcessor();
    media = MediaProcessingService(
      db: library.db,
      sources: _NoSources(),
      root: Future.value(Directory('${tmp.path}/media')),
      processor: processor,
    );
    fakeBackend = FakeAsrBackend();
    registry = AsrBackendRegistry(
      db: library.configuration,
      models: AsrModelStore(Future.value(Directory('${tmp.path}/models'))),
      backendFactory: (_) => fakeBackend,
    );
    service = SubtitleGenerationService(
      db: library.db,
      media: media,
      backends: registry,
      root: Future.value(Directory('${tmp.path}/subtitles')),
    );
  });

  tearDown(() {
    service.dispose();
    media.dispose();
    library.close();
    tmp.deleteSync(recursive: true);
  });

  test('inspect lists audio tracks and validates errors', () async {
    final ref = ResourceRef('@local', sampleFile.path);
    final info = await service.inspect(ref);
    expect(info.durationMs, 120000);
    expect(info.tracks, hasLength(1));
    expect(info.defaultTrack!.codec, 'aac');
    expect(SubtitleGenerationService.estimateWavBytes(1000), 32044);

    processor.probeError = const MediaException(MediaErrorCode.unavailable);
    await expectLater(
      service.inspect(ref),
      throwsA(
        isA<SubtitleException>().having((e) => e.code, 'code', 'ffmpeg_unavailable'),
      ),
    );
  });

  test('extract-only, transcribe range, cache reuse, save and bindings', () async {
    final ref = ResourceRef('@local', sampleFile.path);
    final info = await service.inspect(ref);
    final trackRef = info.defaultTrack!.ref;

    // 1. Extract audio only (no ASR call).
    final extractRun = service.start(
      SubtitleRequest(
        resource: ref,
        resourceName: 'episode.mp4',
        caller: SubtitleCaller.debug,
        trackRef: trackRef,
        startMs: 10000,
        endMs: 20000,
        transcribe: false,
      ),
    );
    final extracted = await extractRun.done;
    expect(extracted.status, SubtitleRunStatus.succeeded);
    expect(extracted.audio, isNotNull);
    expect(fakeBackend.calls, 0);

    // 2. Transcribe same range: reuses extracted audio and produces cues.
    final first = await service
        .start(
          SubtitleRequest(
            resource: ref,
            resourceName: 'episode.mp4',
            caller: SubtitleCaller.debug,
            trackRef: trackRef,
            startMs: 10000,
            endMs: 20000,
            language: 'en',
          ),
        )
        .done;
    expect(first.status, SubtitleRunStatus.succeeded);
    expect(first.audio!.reused, isTrue);
    expect(first.transcript!.segments.first.startMs, 10500);
    expect(first.cues, isNotEmpty);
    expect(fakeBackend.calls, 1);

    // 3. Second identical run hits transcript cache (no second ASR call).
    final cached = await service
        .start(
          SubtitleRequest(
            resource: ref,
            resourceName: 'episode.mp4',
            caller: SubtitleCaller.debug,
            trackRef: trackRef,
            startMs: 10000,
            endMs: 20000,
            language: 'en',
          ),
        )
        .done;
    expect(cached.status, SubtitleRunStatus.succeeded);
    expect(fakeBackend.calls, 1);

    // 4. Save creates a partial binding and artifacts.
    expect(service.bindings(ref), isEmpty);
    final saved = await service.save(first.taskId, format: SubtitleFormat.srt);
    expect(saved['partial'], isTrue);
    expect(saved['format'], 'srt');
    final bindings = service.bindings(ref);
    expect(bindings, hasLength(1));
    expect(bindings.first['partial'], isTrue);
    expect(service.task(first.taskId)!['status'], 'succeeded');
  });

  test('whole-media chunked transcription and AI save', () async {
    // 13 minutes so wholeMedia splits into multiple chunks.
    processor.probeResult = fakeMediaProbe(durationUs: 13 * 60 * 1000000);
    final ref = ResourceRef('@local', sampleFile.path);
    final state = await service
        .start(
          SubtitleRequest(
            resource: ref,
            resourceName: 'long_movie.mp4',
            caller: SubtitleCaller.ai,
            wholeMedia: true,
            language: 'en',
          ),
        )
        .done;
    expect(state.status, SubtitleRunStatus.succeeded);
    expect(state.transcript!.wholeMedia, isTrue);
    expect(fakeBackend.calls, greaterThanOrEqualTo(2));
    final saved = await service.save(state.taskId, format: SubtitleFormat.vtt);
    expect(saved['partial'], isFalse);
    expect(saved['format'], 'vtt');
  });

  test('DebugSubtitleSession enforces resource scope, cancel and discard', () async {
    final ref = ResourceRef('@local', sampleFile.path);
    final session = DebugSubtitleSession(service, ref);
    expect(
      () => session.start(
        SubtitleRequest(
          resource: const ResourceRef('@local', '/other.mp4'),
          resourceName: 'other.mp4',
          caller: SubtitleCaller.debug,
          startMs: 0,
          endMs: 5000,
        ),
      ),
      throwsA(
        isA<SubtitleException>().having((e) => e.code, 'code', 'access_denied'),
      ),
    );

    final hold = Completer<void>();
    fakeBackend.holdCompleter = hold;
    final run = session.start(
      SubtitleRequest(
        resource: ref,
        resourceName: 'episode.mp4',
        caller: SubtitleCaller.debug,
        startMs: 0,
        endMs: 5000,
      ),
    );
    // Dedup active run
    expect(
      session
          .start(
            SubtitleRequest(
              resource: ref,
              resourceName: 'episode.mp4',
              caller: SubtitleCaller.debug,
              startMs: 0,
              endMs: 5000,
            ),
          )
          .taskId,
      run.taskId,
    );

    final closeFuture = session.close();
    hold.complete();
    await closeFuture;
    expect((await run.done).status, SubtitleRunStatus.cancelled);

    // Closed session refuses new starts.
    expect(
      () => session.start(
        SubtitleRequest(
          resource: ref,
          resourceName: 'episode.mp4',
          caller: SubtitleCaller.debug,
          startMs: 0,
          endMs: 5000,
        ),
      ),
      throwsA(isA<SubtitleException>().having((e) => e.code, 'code', 'closed')),
    );
  });

  test('validation errors, silent transcript and recover cleanup', () async {
    final ref = ResourceRef('@local', sampleFile.path);
    expect(
      () => service.start(
        SubtitleRequest(
          resource: ref,
          resourceName: 'e.mp4',
          caller: SubtitleCaller.debug,
          startMs: 10000,
          endMs: 5000,
        ),
      ),
      throwsA(
        isA<SubtitleException>().having((e) => e.code, 'code', 'invalid_range'),
      ),
    );

    // Unavailable backend
    fakeBackend.available = false;
    fakeBackend.unavailableReason = 'model_missing';
    final missing = await service
        .start(
          SubtitleRequest(
            resource: ref,
            resourceName: 'e.mp4',
            caller: SubtitleCaller.debug,
            startMs: 0,
            endMs: 5000,
          ),
        )
        .done;
    expect(missing.status, SubtitleRunStatus.failed);
    expect(missing.error, 'model_missing');

    // Silent transcript succeeds with empty cues; save rejects empty transcript.
    fakeBackend.available = true;
    fakeBackend.segments = const [RawSegment(0, 1000, '[BLANK_AUDIO]')];
    final silent = await service
        .start(
          SubtitleRequest(
            resource: ref,
            resourceName: 'e.mp4',
            caller: SubtitleCaller.debug,
            startMs: 0,
            endMs: 5000,
          ),
        )
        .done;
    expect(silent.status, SubtitleRunStatus.succeeded);
    expect(silent.cues, isEmpty);
    await expectLater(
      service.save(silent.taskId),
      throwsA(
        isA<SubtitleException>().having((e) => e.code, 'code', 'transcript_empty'),
      ),
    );

    // Recover cleans debug leftovers & marks running tasks interrupted.
    final savedDir = Directory('${tmp.path}/subtitles/saved')
      ..createSync(recursive: true);
    final stray = File('${savedDir.path}/stray.part')..writeAsStringSync('x');
    await service.recover();
    expect(stray.existsSync(), isFalse);
  });

  test('Transcript JSON round-trip and normalizer filters annotations', () {
    final t = Transcript(
      resourceRef: 'r1',
      audioTrackRef: 'track:1:abcd',
      rangeStartMs: 1000,
      rangeEndMs: 5000,
      language: 'en',
      backend: 'platform',
      modelId: 'whisper-large-v3',
      modelRevision: 'rev1',
      engineVersion: '1.0',
      segments: const [TranscriptSegment(1200, 2500, 'Hi there')],
    );
    final decoded = Transcript.fromJson(t.toJson());
    expect(decoded.segments.single.text, 'Hi there');
    expect(decoded.rangeStartMs, 1000);
  });
}
