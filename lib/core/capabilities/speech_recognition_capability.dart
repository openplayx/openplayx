import 'package:openplayx_whisper/openplayx_whisper.dart' show RawTranscript;

export 'package:openplayx_whisper/openplayx_whisper.dart' show RawTranscript;

/// Workflow stages a recognition reports (design §9). Embedded backends skip
/// `uploading`/`queued`.
enum AsrStage {
  preparing,
  extracting,
  uploading,
  queued,
  transcribing,
  formatting,
}

/// Cooperative cancellation shared by the workflow and a backend.
class AsrCancelToken {
  bool _cancelled = false;
  final _listeners = <void Function()>[];
  bool get cancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final l in [..._listeners]) {
      l();
    }
  }

  void onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }
}

/// Task context handed to a backend: cancellation and stage progress.
class AsrTaskContext {
  AsrTaskContext({required this.cancel, required this.report, this.remoteJob});
  final AsrCancelToken cancel;
  final void Function(AsrStage stage, {int? processedMs, int? totalMs}) report;

  /// Called as soon as a remote service accepted a job, so the host can
  /// reconcile or clean it up after a disconnect or cancellation.
  final void Function(String remoteJobId)? remoteJob;
}

/// One normalised audio input (16 kHz mono s16 WAV) in audio-local time.
class TranscriptionRequest {
  const TranscriptionRequest({
    required this.audioPath,
    required this.audioMs,
    required this.audioSha256,
    this.language = 'auto',
  });
  final String audioPath;
  final int audioMs;

  /// Input checksum: idempotency/validation for uploads, cache keys locally.
  final String audioSha256;
  final String language;
}

/// Backend output still in `audio_ms` (relative to the uploaded audio).
class TranscriptResult {
  const TranscriptResult({
    required this.raw,
    required this.backend,
    required this.modelId,
    required this.modelRevision,
    required this.engineVersion,
    this.remoteJobId,
  });
  final RawTranscript raw;

  /// `embedded` or `http`.
  final String backend;
  final String modelId;
  final String modelRevision;
  final String engineVersion;
  final String? remoteJobId;
}

class AsrBackendStatus {
  const AsrBackendStatus({
    required this.available,
    this.reason,
    this.modelId,
    this.modelRevision,
    this.engineVersion,
    this.limits = const {},
  });
  final bool available;

  /// Short machine reason when unavailable (`model_not_installed`, …).
  final String? reason;
  final String? modelId;
  final String? modelRevision;
  final String? engineVersion;
  final Map<String, Object?> limits;
}

class AsrBackendException implements Exception {
  const AsrBackendException(this.code, {this.retryable = false});

  /// Short code such as `backend_unreachable`, `model_not_installed`.
  final String code;
  final bool retryable;
  @override
  String toString() => 'AsrBackendException($code)';
}

/// `model.transcribe` (plugin design §12.43). The host selects an instance;
/// extraction, windowing and subtitle serialisation are host workflow code.
abstract interface class SpeechRecognitionModelCapability {
  String get instanceId;

  /// `embedded` | `http`.
  String get kind;
  Future<AsrBackendStatus> status();
  Future<TranscriptResult> transcribe(
    TranscriptionRequest request,
    AsrTaskContext context,
  );
}
