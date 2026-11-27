import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:openplayx/core/capabilities/speech_recognition_capability.dart';
import 'package:openplayx_ffmpeg/openplayx_ffmpeg.dart';
import 'package:openplayx_whisper/openplayx_whisper.dart';

/// Writes a valid 16 kHz mono 16-bit PCM WAV file of [durationMs] silence.
File writeFakeWav(File file, {int durationMs = 5000}) {
  final samples = (16000 * durationMs) ~/ 1000;
  final dataBytes = samples * 2;
  final out = ByteData(44 + dataBytes);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      out.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  out.setUint32(4, 36 + dataBytes, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  out.setUint32(16, 16, Endian.little);
  out.setUint16(20, 1, Endian.little); // PCM
  out.setUint16(22, 1, Endian.little); // mono
  out.setUint32(24, 16000, Endian.little); // sample rate
  out.setUint32(28, 32000, Endian.little); // byte rate
  out.setUint16(32, 2, Endian.little); // block align
  out.setUint16(34, 16, Endian.little); // bits per sample
  tag(36, 'data');
  out.setUint32(40, dataBytes, Endian.little);
  file.parent.createSync(recursive: true);
  return file..writeAsBytesSync(out.buffer.asUint8List());
}

/// Default fake probe: 120s MP4 with H.264 video + AAC stereo audio + SRT sub.
MediaProbe fakeMediaProbe({
  int durationUs = 120 * 1000000,
  bool hasVideo = true,
  bool hasAudio = true,
  bool audioDecodable = true,
}) => MediaProbe.fromJson({
  'container': 'mov,mp4,m4a,3gp,3g2,mj2',
  'duration_us': durationUs,
  'bit_rate': 1200000,
  'streams': [
    if (hasVideo)
      {
        'index': 0,
        'type': 'video',
        'codec': 'h264',
        'decodable': true,
        'duration_us': durationUs,
        'width': 1280,
        'height': 720,
        'fps_num': 30,
        'fps_den': 1,
        'avg_fps_num': 30,
        'avg_fps_den': 1,
        'default': true,
      },
    if (hasAudio)
      {
        'index': 1,
        'type': 'audio',
        'codec': 'aac',
        'decodable': audioDecodable,
        'duration_us': durationUs,
        'sample_rate': 48000,
        'channels': 2,
        'language': 'eng',
        'title': 'English',
        'default': true,
      },
    {
      'index': 2,
      'type': 'subtitle',
      'codec': 'subrip',
      'decodable': true,
      'language': 'eng',
    },
  ],
});

MediaCapabilities fakeMediaCapabilities() => MediaCapabilities.fromJson({
  'available': true,
  'ffmpeg': '7.1-fake',
  'encoders': ['libx264', 'aac', 'pcm_s16le', 'mjpeg', 'libwebp', 'png'],
  'muxers': ['mp4', 'matroska', 'wav', 'image2', 'mjpeg', 'webp'],
  'decoders': ['h264', 'hevc', 'aac', 'mp3', 'opus', 'pcm_s16le', 'subrip'],
});

class FakeMediaJob implements MediaJob {
  FakeMediaJob({
    required this.plan,
    required this.output,
    this.delay = Duration.zero,
    this.failWith,
    this.holdCompleter,
    this.wavDurationMs = 5000,
  }) {
    unawaited(_run());
  }

  @override
  final MediaPlan plan;
  @override
  final String output;
  final Duration delay;
  final MediaErrorCode? failWith;
  final Completer<void>? holdCompleter;
  final int wavDurationMs;

  final _progress = StreamController<MediaJobProgress>.broadcast();
  final _done = Completer<MediaJobResult>();
  MediaJobProgress _current = const MediaJobProgress(MediaJobState.queued);
  bool _cancelled = false;

  @override
  Stream<MediaJobProgress> get progress => _progress.stream;
  @override
  MediaJobProgress get current => _current;
  @override
  Future<MediaJobResult> get done => _done.future;

  void _emit(MediaJobProgress p) {
    _current = p;
    if (!_progress.isClosed) _progress.add(p);
  }

  @override
  void cancel() {
    if (_cancelled || _current.state.terminal) return;
    _cancelled = true;
    _emit(
      MediaJobProgress(
        MediaJobState.cancelling,
        processed: _current.processed,
        total: _current.total,
      ),
    );
    if (holdCompleter != null && !holdCompleter!.isCompleted) {
      holdCompleter!.complete();
    }
  }

  Future<void> _run() async {
    try {
      _emit(
        const MediaJobProgress(
          MediaJobState.running,
          processed: Duration(milliseconds: 500),
          total: Duration(seconds: 10),
        ),
      );
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (holdCompleter != null) await holdCompleter!.future;
      if (_cancelled) {
        _finish(
          const MediaJobResult(
            MediaJobState.cancelled,
            error: MediaErrorCode.cancelled,
          ),
        );
        return;
      }
      if (failWith != null) {
        _finish(MediaJobResult(MediaJobState.failed, error: failWith));
        return;
      }
      final file = File(output);
      file.parent.createSync(recursive: true);
      if (plan.extension == 'wav') {
        writeFakeWav(file, durationMs: wavDurationMs);
      } else {
        file.writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      }
      _finish(
        MediaJobResult(
          MediaJobState.succeeded,
          outputPath: file.path,
          bytes: file.lengthSync(),
        ),
      );
    } catch (_) {
      _finish(
        const MediaJobResult(
          MediaJobState.failed,
          error: MediaErrorCode.nativeFailure,
        ),
      );
    }
  }

  void _finish(MediaJobResult r) {
    if (_done.isCompleted) return;
    _emit(MediaJobProgress(r.state, error: r.error));
    _done.complete(r);
    unawaited(_progress.close());
  }
}

class FakeMediaProcessor implements MediaProcessor {
  FakeMediaProcessor({
    this.isAvailable = true,
    MediaProbe? probeResult,
    MediaCapabilities? caps,
    this.probeError,
    this.failJobWith,
    this.jobDelay = Duration.zero,
    this.holdNextJob,
    this.wavDurationMs = 5000,
  }) : probeResult = probeResult ?? fakeMediaProbe(),
       caps = caps ?? fakeMediaCapabilities();

  bool isAvailable;
  MediaProbe probeResult;
  MediaCapabilities caps;
  Object? probeError;
  MediaErrorCode? failJobWith;
  Duration jobDelay;
  Completer<void>? holdNextJob;
  int wavDurationMs;
  int submitCount = 0;
  int probeCount = 0;
  bool disposed = false;

  @override
  Duration get pollInterval => const Duration(milliseconds: 10);

  @override
  bool get available => isAvailable;

  @override
  Future<MediaCapabilities> capabilities() async =>
      isAvailable ? caps : const MediaCapabilities.unavailable();

  @override
  Future<MediaProbe> probe(
    String input, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    probeCount++;
    if (!isAvailable) throw const MediaException(MediaErrorCode.unavailable);
    if (probeError != null) throw probeError!;
    if (input.endsWith('.wav')) {
      final f = File(input);
      final bytes = f.existsSync() ? f.lengthSync() : 44 + wavDurationMs * 32;
      final durUs = ((bytes - 44).clamp(0, 1 << 30) ~/ 32) * 1000;
      return MediaProbe.fromJson({
        'container': 'wav',
        'duration_us': durUs,
        'bit_rate': 256000,
        'streams': [
          {
            'index': 0,
            'type': 'audio',
            'codec': 'pcm_s16le',
            'decodable': true,
            'duration_us': durUs,
            'sample_rate': 16000,
            'channels': 1,
            'default': true,
          },
        ],
      });
    }
    return probeResult;
  }

  @override
  MediaJob submit(
    MediaPlan plan, {
    required String input,
    required String output,
  }) {
    submitCount++;
    final hold = holdNextJob;
    holdNextJob = null;
    final startUs = plan.values['start_us'] as int?;
    final endUs = plan.values['end_us'] as int?;
    final dur = startUs != null && endUs != null
        ? ((endUs - startUs) ~/ 1000).clamp(500, 600000)
        : wavDurationMs;
    return FakeMediaJob(
      plan: plan,
      output: output,
      delay: jobDelay,
      failWith: failJobWith,
      holdCompleter: hold,
      wavDurationMs: dur,
    );
  }

  @override
  void dispose() {
    disposed = true;
  }
}

class FakeAsrBackend implements SpeechRecognitionModelCapability {
  FakeAsrBackend({
    this.instanceId = 'platform',
    this.kind = 'platform',
    this.available = true,
    this.unavailableReason,
    this.modelId = 'whisper-large-v3',
    this.segments = const [
      RawSegment(500, 2000, 'Hello world'),
      RawSegment(2200, 4000, 'Second line'),
    ],
    this.failWith,
    this.holdCompleter,
    this.remoteJobId,
  });

  @override
  final String instanceId;
  @override
  final String kind;
  bool available;
  String? unavailableReason;
  String modelId;
  List<RawSegment> segments;
  Object? failWith;
  Completer<void>? holdCompleter;
  String? remoteJobId;
  int calls = 0;

  @override
  Future<AsrBackendStatus> status() async => AsrBackendStatus(
    available: available,
    reason: unavailableReason,
    modelId: modelId,
  );

  @override
  Future<TranscriptResult> transcribe(
    TranscriptionRequest input,
    AsrTaskContext context,
  ) async {
    calls++;
    context.report(
      AsrStage.transcribing,
      processedMs: 0,
      totalMs: input.audioMs,
    );
    if (remoteJobId != null) context.remoteJob?.call(remoteJobId!);
    if (holdCompleter != null) await holdCompleter!.future;
    if (context.cancel.cancelled) {
      throw const AsrBackendException('cancelled', retryable: true);
    }
    if (failWith != null) throw failWith!;
    context.report(
      AsrStage.transcribing,
      processedMs: input.audioMs,
      totalMs: input.audioMs,
    );
    return TranscriptResult(
      raw: RawTranscript(
        language: input.language == 'auto' ? 'en' : input.language,
        audioMs: input.audioMs,
        windowMs: input.audioMs,
        overlapMs: 0,
        windows: [RawWindow(0, input.audioMs, segments)],
      ),
      backend: kind,
      modelId: modelId,
      modelRevision: 'rev-test',
      engineVersion: 'fake-1.0',
      remoteJobId: remoteJobId,
    );
  }
}
