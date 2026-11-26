import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/core/capabilities/speech_recognition_capability.dart';
import 'package:openplayx/capabilities/media_processing/media_processing_service.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/capabilities/speech/asr_backend_config.dart';
import 'package:openplayx/capabilities/speech/asr_model_store.dart';
import 'package:openplayx/capabilities/speech/subtitle_generation_service.dart';
import 'package:openplayx/capabilities/speech/subtitle_format.dart';
import 'package:openplayx_ffmpeg/openplayx_ffmpeg.dart';
import 'package:openplayx_whisper/openplayx_whisper.dart';
import 'package:sqlite3/sqlite3.dart';

class _Backend implements SpeechRecognitionModelCapability {
  int calls = 0;
  int? failCall;
  void Function(AsrTaskContext)? onCall;
  final lengths = <int>[];
  @override
  String get instanceId => 'platform';
  @override
  String get kind => 'platform';
  @override
  Future<AsrBackendStatus> status() async => const AsrBackendStatus(
    available: true,
    modelId: 'whisper-large-v3',
    modelRevision: 'fixture-v1',
  );
  @override
  Future<TranscriptResult> transcribe(
    TranscriptionRequest r,
    AsrTaskContext context,
  ) async {
    calls++;
    lengths.add(r.audioMs);
    onCall?.call(context);
    if (calls == failCall) throw const AsrBackendException('backend_error');
    return TranscriptResult(
      raw: RawTranscript(
        language: 'en',
        audioMs: r.audioMs,
        windowMs: r.audioMs,
        overlapMs: 0,
        windows: [
          RawWindow(0, r.audioMs, [
            if (r.audioMs > 303000)
              const RawSegment(1000, 3000, 'Boundary sentence'),
            RawSegment(3000, 4000, 'Line ${r.audioMs}'),
            if (r.audioMs > 300000 && r.audioMs < 303000)
              const RawSegment(300500, 301500, 'Boundary sentence'),
          ]),
        ],
      ),
      backend: kind,
      modelId: 'whisper-large-v3',
      modelRevision: 'fixture-v1',
      engineVersion: 'fixture',
    );
  }
}

void main() {
  final ext = Platform.isMacOS ? 'dylib' : 'so';
  final ffmpeg = File('../ffmpeg-package/build/host/libopenplayx_ffmpeg.$ext')
      .absolute
      .path;
  test('whole movie extracts bounded chunks; retry survives discard and restart; offsets and save are correct', () async {
    final tmp = await Directory.systemTemp.createTemp('opx_full_subtitles');
    final db = sqlite3.openInMemory();
    final input = File('${tmp.path}/movie.wav');
    final bytes = ByteData(44);
    void tag(int at, String text) {
      for (var i = 0; i < text.length; i++) {
        bytes.setUint8(at + i, text.codeUnitAt(i));
      }
    }

    const pcmSize = 720 * 32000;
    tag(0, 'RIFF');
    bytes.setUint32(4, pcmSize + 36, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, 16000, Endian.little);
    bytes.setUint32(28, 32000, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    tag(36, 'data');
    bytes.setUint32(40, pcmSize, Endian.little);
    final wav = await input.open(mode: FileMode.write);
    await wav.writeFrom(bytes.buffer.asUint8List());
    await wav.truncate(pcmSize + 44);
    await wav.close();
    final media = MediaProcessingService(
      db: db,
      sources: SourceManager(),
      root: Future.value(Directory('${tmp.path}/media')),
      processor: MediaProcessor(
        libraryPath: ffmpeg,
        pollInterval: const Duration(milliseconds: 5),
      ),
    );
    final backend = _Backend()..failCall = 2;
    final registry = AsrBackendRegistry(
      db: db,
      models: AsrModelStore(Future.value(null)),
      backendFactory: (_) => backend,
    );
    SubtitleGenerationService create() => SubtitleGenerationService(
      db: db,
      media: media,
      backends: registry,
      root: Future.value(Directory('${tmp.path}/subtitles')),
    );
    var service = create();
    addTearDown(() async {
      service.dispose();
      media.dispose();
      db.close();
      await tmp.delete(recursive: true);
    });
    final request = SubtitleRequest(
      resource: ResourceRef('@local', input.path),
      resourceName: 'movie.wav',
      caller: SubtitleCaller.debug,
      wholeMedia: true,
    );
    final failed = await service.start(request).done;
    expect(failed.status, SubtitleRunStatus.failed);
    expect(failed.error, 'backend_error');
    expect(backend.calls, 2);
    await service.discard(failed.taskId);
    service.dispose();
    service = create();
    await service.recover();
    backend.failCall = null;
    final result = await service.start(request).done;
    expect(result.status, SubtitleRunStatus.succeeded, reason: result.error);
    expect(
      backend.calls,
      4,
      reason: 'the first complete chunk must not upload again',
    );
    expect(backend.lengths.every((ms) => ms <= 304000), isTrue);
    expect(result.transcript!.wholeMedia, isTrue);
    expect(result.transcript!.segments.map((s) => s.startMs), [
      3000,
      299000,
      301000,
      601000,
    ]);
    expect(
      result.transcript!.segments.where((s) => s.text == 'Boundary sentence'),
      hasLength(1),
    );
    expect(result.completedAudioMs, 720000);
    final saved = await service.save(result.taskId, format: SubtitleFormat.srt);
    expect(saved['partial'], isFalse);
    expect(
      service.subtitleText(result.taskId, SubtitleFormat.srt),
      contains('00:05:01,000'),
    );
    expect(
      db.select('SELECT * FROM media_artifacts WHERE kind=?', ['audio']),
      isEmpty,
    );
    // A new language creates a new cache namespace. Cancel in the second
    // chunk, and ensure no complete subtitle or late success is published.
    final beforeCancel = backend.calls;
    late SubtitleRun cancelRun;
    backend.onCall = (_) {
      if (backend.calls == beforeCancel + 2) cancelRun.cancel();
    };
    cancelRun = service.start(
      SubtitleRequest(
        resource: request.resource,
        resourceName: request.resourceName,
        caller: SubtitleCaller.debug,
        wholeMedia: true,
        language: 'zh',
      ),
    );
    final cancelled = await cancelRun.done;
    expect(cancelled.status, SubtitleRunStatus.cancelled);
    expect(cancelled.transcript, isNull);
    expect(backend.calls, beforeCancel + 2);
  }, skip: !File(ffmpeg).existsSync() ? 'build host FFmpeg bridge' : false);
}
