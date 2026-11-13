// End-to-end: real in-process FFmpeg extraction + real whisper.cpp
// recognition. Needs ../ffmpeg-package/tool/build_host_lib.sh,
// ../whisper-package/tool/build_host_lib.sh and a ggml-tiny.bin model in
// ~/.cache/openplayx-asr-models (or OPX_WHISPER_TINY_MODEL). Skipped otherwise.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/core/plugins/speech_recognition_capability.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/services/media_processing/media_processing_service.dart';
import 'package:openplayx/services/subtitles/asr_backend_config.dart';
import 'package:openplayx/services/subtitles/asr_model_store.dart';
import 'package:openplayx/services/subtitles/subtitle_format.dart';
import 'package:openplayx/services/subtitles/subtitle_generation_service.dart';
import 'package:openplayx_ffmpeg/openplayx_ffmpeg.dart';
import 'package:openplayx_whisper/openplayx_whisper.dart';
import 'package:sqlite3/sqlite3.dart';

class _Sources extends SourceManager {
  @override
  Future<void> load() async {}
}

/// 32 kHz stereo copy of a 16 kHz mono WAV: extraction must really
/// resample and down-mix, not relabel the header.
File stereo32k(File mono, String path) {
  final src = mono.readAsBytesSync();
  final pcm = ByteData.sublistView(src, 44);
  final n = pcm.lengthInBytes ~/ 2;
  final out = ByteData(44 + n * 8);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      out.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  out.setUint32(4, 36 + n * 8, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  out.setUint32(16, 16, Endian.little);
  out.setUint16(20, 1, Endian.little);
  out.setUint16(22, 2, Endian.little);
  out.setUint32(24, 32000, Endian.little);
  out.setUint32(28, 32000 * 4, Endian.little);
  out.setUint16(32, 4, Endian.little);
  out.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  out.setUint32(40, n * 8, Endian.little);
  for (var i = 0; i < n; i++) {
    final v = pcm.getInt16(i * 2, Endian.little);
    for (var k = 0; k < 4; k++) {
      out.setInt16(44 + i * 8 + k * 2, v, Endian.little);
    }
  }
  return File(path)..writeAsBytesSync(out.buffer.asUint8List());
}

void main() {
  final ext = Platform.isMacOS ? 'dylib' : 'so';
  final ffmpeg = File('../ffmpeg-package/build/host/libopenplayx_ffmpeg.$ext').absolute.path;
  final whisper = File('../whisper-package/build/host/libopenplayx_whisper.$ext').absolute.path;
  final model =
      Platform.environment['OPX_WHISPER_TINY_MODEL'] ??
      '${Platform.environment['HOME']}/.cache/openplayx-asr-models/ggml-tiny.bin';
  final skip = !File(ffmpeg).existsSync()
      ? 'build the host FFmpeg bridge'
      : !File(whisper).existsSync()
      ? 'build the host whisper bridge'
      : !File(model).existsSync()
      ? 'no tiny model'
      : null;

  late Directory tmp;
  late Directory models;
  late LibraryService library;
  late MediaProcessingService media;
  late AsrBackendRegistry registry;
  late SubtitleGenerationService service;
  late String input;
  final engine = WhisperEngine(libraryPath: whisper, pollInterval: const Duration(milliseconds: 20));

  setUpAll(() async {
    if (skip != null) return;
    models = Directory.systemTemp.createTempSync('opx_asr_models');
    await AsrModelStore(Future.value(models)).import(File(model));
  });
  tearDownAll(() {
    if (skip == null) models.deleteSync(recursive: true);
  });

  setUp(() {
    if (skip != null) return;
    tmp = Directory.systemTemp.createTempSync('opx_sub');
    input = stereo32k(File('../whisper-package/test/fixtures/long.wav'), '${tmp.path}/episode.wav').path;
    library = LibraryService(sqlite3.openInMemory());
    media = MediaProcessingService(
      db: library.db,
      sources: _Sources(),
      root: Future.value(Directory('${tmp.path}/media')),
      processor: MediaProcessor(libraryPath: ffmpeg, pollInterval: const Duration(milliseconds: 20)),
    );
    registry = AsrBackendRegistry(
      db: library.db,
      models: AsrModelStore(Future.value(models)),
      embeddedEngine: engine,
      readCredential: (_) async => null,
    );
    registry.save(registry.get('embedded')!.copyWith(modelId: 'whisper-tiny-multilingual', language: 'en'));
    service = SubtitleGenerationService(
      db: library.db,
      media: media,
      backends: registry,
      root: Future.value(Directory('${tmp.path}/subtitles')),
    );
  });
  tearDown(() {
    if (skip != null) return;
    service.dispose();
    media.dispose();
    library.close();
    tmp.deleteSync(recursive: true);
  });

  ResourceRef ref() => ResourceRef('@local', input);

  test('inspect lists the audio track without recognising anything', () async {
    final info = await service.inspect(ref());
    expect(info.tracks, hasLength(1));
    expect(info.tracks.single.channels, 2);
    expect(info.durationMs, inInclusiveRange(49000, 50000));
    expect(library.db.select('SELECT * FROM transcription_tasks'), isEmpty);
  }, skip: skip);

  test('extract only: 16 kHz mono of the exact range, no model or upload', () async {
    final run = service.start(SubtitleRequest(
      resource: ref(),
      resourceName: 'episode.wav',
      caller: SubtitleCaller.debug,
      endMs: 60000,
      transcribe: false,
    ));
    final s = await run.done;
    expect(s.status, SubtitleRunStatus.succeeded, reason: s.error);
    expect(s.audio!.sampleRate, 16000);
    expect(s.audio!.channels, 1);
    // Clamped to the real duration.
    expect(s.audio!.durationMs, inInclusiveRange(49000, 50000));
    expect(s.transcript, isNull);
    expect(s.stageMs.keys, isNot(contains('transcribing')));
  }, skip: skip);

  test('range recognition maps back to the original media time', () async {
    final run = service.start(SubtitleRequest(
      resource: ref(),
      resourceName: 'episode.wav',
      caller: SubtitleCaller.debug,
      startMs: 35000,
      endMs: 50000,
      backendId: 'embedded',
    ));
    final stages = <AsrStage>{};
    run.updates.listen((s) => stages.add(s.stage));
    final s = await run.done;
    expect(s.status, SubtitleRunStatus.succeeded, reason: s.error);
    expect(stages, containsAll([AsrStage.extracting, AsrStage.transcribing, AsrStage.formatting]));
    expect(stages, isNot(contains(AsrStage.uploading)));
    final t = s.transcript!;
    expect(t.rangeStartMs, 35000);
    expect(t.wholeMedia, isFalse);
    expect(t.segments, isNotEmpty);
    // Speech starts at 41.0 s of the media, i.e. 6 s into the extracted range.
    expect(t.segments.first.startMs, inInclusiveRange(40300, 41700));
    expect(t.segments.map((x) => x.text).join(' ').toLowerCase(), contains('fox'));
    final srt = service.subtitleText(run.taskId, SubtitleFormat.srt);
    expect(srt, contains('00:00:4'));
  }, skip: skip);

  test('second run reuses the extraction and the transcript', () async {
    final r = SubtitleRequest(
      resource: ref(),
      resourceName: 'episode.wav',
      caller: SubtitleCaller.ai,
      startMs: 40000,
      endMs: 48000,
      backendId: 'embedded',
    );
    final first = await service.start(r).done;
    expect(first.audio!.reused, isFalse);
    final second = await service.start(r).done;
    expect(second.status, SubtitleRunStatus.succeeded);
    expect(second.audio!.reused, isTrue);
    expect(second.audio!.artifactId, first.audio!.artifactId);
    expect(library.db.select("SELECT * FROM processing_tasks WHERE preset_id='audio.speech.wav'"), hasLength(1));
  }, skip: skip);

  test('same request while running maps to the same task', () async {
    final r = SubtitleRequest(
      resource: ref(),
      resourceName: 'episode.wav',
      caller: SubtitleCaller.debug,
      endMs: 20000,
      transcribe: false,
    );
    final a = service.start(r);
    final b = service.start(r);
    expect(b.taskId, a.taskId);
    await a.done;
  }, skip: skip);

  test('saving creates a partial binding; nothing is bound before', () async {
    final run = service.start(SubtitleRequest(
      resource: ref(),
      resourceName: 'episode.wav',
      caller: SubtitleCaller.debug,
      startMs: 38000,
      endMs: 49000,
      backendId: 'embedded',
    ));
    await run.done;
    expect(service.bindings(ref()), isEmpty);
    final saved = await service.save(run.taskId, format: SubtitleFormat.vtt);
    expect(saved['partial'], isTrue);
    final b = service.bindings(ref()).single;
    expect(b['range_start_ms'], 38000);
    final path = media.artifactPath(saved['subtitle_artifact_ref'] as String)!;
    expect(File(path).readAsStringSync(), startsWith('WEBVTT'));
    // A second save is a new subtitle, never an overwrite.
    await service.save(run.taskId);
    expect(service.bindings(ref()), hasLength(2));
  }, skip: skip);

  test('closing the debug session cancels and discards unsaved output', () async {
    final session = DebugSubtitleSession(service, ref());
    final done = await session.start(SubtitleRequest(
      resource: ref(),
      resourceName: 'episode.wav',
      caller: SubtitleCaller.debug,
      endMs: 10000,
      transcribe: false,
    )).done;
    final audio = media.artifactPath(done.audio!.artifactId)!;
    final running = session.start(SubtitleRequest(
      resource: ref(),
      resourceName: 'episode.wav',
      caller: SubtitleCaller.debug,
      startMs: 30000,
      endMs: 49000,
      backendId: 'embedded',
    ));
    await running.updates.firstWhere((s) => s.stage == AsrStage.transcribing);
    await session.close();
    expect(running.current.status, SubtitleRunStatus.cancelled);
    expect(File(audio).existsSync(), isFalse);
    expect(
      () => session.start(SubtitleRequest(resource: ref(), resourceName: 'x', caller: SubtitleCaller.debug, endMs: 1000, transcribe: false)),
      throwsA(isA<SubtitleException>()),
    );
  }, skip: skip);

  test('debug session refuses another resource', () {
    final session = DebugSubtitleSession(service, ref());
    expect(
      () => session.start(SubtitleRequest(
        resource: const ResourceRef('@local', '/etc/passwd'),
        resourceName: 'x',
        caller: SubtitleCaller.debug,
        endMs: 1000,
        transcribe: false,
      )),
      throwsA(isA<SubtitleException>().having((e) => e.code, 'code', 'access_denied')),
    );
  }, skip: skip);

  test('HTTP backend needs upload consent; no automatic fallback', () {
    registry.save(AsrBackendConfig(
      id: 'remote',
      kind: 'http',
      name: 'LAN',
      url: 'https://asr.example.test',
      modelId: 'whisper-base-multilingual',
    ));
    expect(
      () => service.start(SubtitleRequest(
        resource: ref(),
        resourceName: 'episode.wav',
        caller: SubtitleCaller.ai,
        endMs: 1000,
        backendId: 'remote',
      )),
      throwsA(isA<SubtitleException>().having((e) => e.code, 'code', 'upload_not_authorized')),
    );
  }, skip: skip);

  test('missing model is reported, not a silent success', () async {
    registry.save(registry.get('embedded')!.copyWith(modelId: 'whisper-small-multilingual'));
    final s = await service.start(SubtitleRequest(
      resource: ref(),
      resourceName: 'episode.wav',
      caller: SubtitleCaller.debug,
      endMs: 5000,
      backendId: 'embedded',
    )).done;
    expect(s.status, SubtitleRunStatus.failed);
    expect(s.error, 'model_not_installed');
  }, skip: skip);

  test('silent range gives an empty transcript', () async {
    final s = await service.start(SubtitleRequest(
      resource: ref(),
      resourceName: 'episode.wav',
      caller: SubtitleCaller.debug,
      startMs: 5000,
      endMs: 20000,
      backendId: 'embedded',
    )).done;
    expect(s.status, SubtitleRunStatus.succeeded, reason: s.error);
    expect(s.transcript!.segments, isEmpty);
    expect(() => service.save(s.taskId), throwsA(isA<SubtitleException>()));
  }, skip: skip);

  test('recover marks unfinished tasks interrupted and clears debug files', () async {
    final s = await service.start(SubtitleRequest(
      resource: ref(),
      resourceName: 'episode.wav',
      caller: SubtitleCaller.debug,
      endMs: 5000,
      transcribe: false,
    )).done;
    final audio = media.artifactPath(s.audio!.artifactId)!;
    library.db.execute("INSERT INTO transcription_tasks (id,caller,transcribe,resource_source,resource_item,resource_name,range_start_ms,state,created,updated) VALUES ('t-x','ai',1,'@local','x','x',0,'running',0,0)");
    await service.recover();
    expect(service.task('t-x')!['status'], 'interrupted');
    expect(File(audio).existsSync(), isFalse);
  }, skip: skip);
}
