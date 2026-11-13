import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:openplayx_whisper/openplayx_whisper.dart';

import '../../core/plugins/speech_recognition_capability.dart';
import 'asr_model_store.dart';

/// On-device recognition through the in-process whisper.cpp bridge. No
/// Python runtime, whisper-server or child process; nothing leaves the
/// device. CPU only, one job at a time, one serially reused model instance.
class EmbeddedWhisperBackend implements SpeechRecognitionModelCapability {
  EmbeddedWhisperBackend({
    required this.store,
    required this._modelId,
    WhisperEngine? engine,
    this.instanceId = 'embedded',
  }) : engine = engine ?? sharedEngine;

  /// One engine per process: its queue enforces concurrency 1.
  static final sharedEngine = WhisperEngine();

  /// The model stays loaded between jobs (loading costs seconds and
  /// hundreds of MB); a different selection replaces it.
  static WhisperModel? _loaded;
  static Future<WhisperModel>? _loading;
  static String? _loadedPath;

  @override
  final String instanceId;
  @override
  String get kind => 'embedded';
  final AsrModelStore store;
  final String Function() _modelId;
  final WhisperEngine engine;

  static int get threads => max(1, min(4, Platform.numberOfProcessors - 1));

  @override
  Future<AsrBackendStatus> status() async {
    final info = engine.info();
    final id = _modelId();
    final spec = asrModelSpec(id);
    if (!info.available) {
      return AsrBackendStatus(
        available: false,
        reason: 'engine_unavailable',
        modelId: id,
      );
    }
    if (spec == null) {
      return AsrBackendStatus(
        available: false,
        reason: 'model_unknown',
        modelId: id,
      );
    }
    final path = await store.path(id);
    return AsrBackendStatus(
      available: path != null,
      reason: path == null ? 'model_not_installed' : null,
      modelId: id,
      modelRevision: spec.revision,
      engineVersion: '${info.engine} ${info.engineVersion}',
      limits: {'concurrency': 1, 'threads': threads, 'gpu': false},
    );
  }

  Future<WhisperModel> _model(String path) async {
    final loaded = _loaded;
    if (loaded != null && !loaded.closed && _loadedPath == path) return loaded;
    final pending = _loading;
    if (pending != null && _loadedPath == path) return pending;
    loaded?.close(); // native keeps it alive for a job still using it
    _loaded = null;
    _loadedPath = path;
    final future = _loading = engine.openModel(path);
    try {
      return _loaded = await future;
    } finally {
      if (identical(_loading, future)) _loading = null;
    }
  }

  /// Releases the loaded model (e.g. on account switch or memory pressure).
  static void unload() {
    _loaded?.close();
    _loaded = null;
    _loadedPath = null;
  }

  static String _error(AsrErrorCode code) => switch (code) {
    AsrErrorCode.modelUnavailable => 'model_unavailable',
    AsrErrorCode.inputUnsupported => 'audio_format_unsupported',
    AsrErrorCode.inputUnavailable => 'audio_unavailable',
    AsrErrorCode.language => 'language_unsupported',
    AsrErrorCode.noMemory => 'out_of_memory',
    AsrErrorCode.cancelled => 'cancelled',
    AsrErrorCode.unavailable => 'engine_unavailable',
    _ => 'recognition_failed',
  };

  @override
  Future<TranscriptResult> transcribe(
    TranscriptionRequest request,
    AsrTaskContext context,
  ) async {
    final s = await status();
    if (!s.available) throw AsrBackendException(s.reason ?? 'unavailable');
    final path = (await store.path(s.modelId!))!;
    if (context.cancel.cancelled) throw const AsrBackendException('cancelled');
    context.report(
      AsrStage.transcribing,
      processedMs: 0,
      totalMs: request.audioMs,
    );
    final WhisperModel model;
    try {
      model = await _model(path);
    } on AsrException catch (e) {
      throw AsrBackendException(_error(e.code));
    }
    final job = engine.transcribe(
      model,
      AsrRequest(
        input: request.audioPath,
        language: request.language,
        threads: threads,
      ),
    );
    context.cancel.onCancel(job.cancel);
    final sub = job.progress.listen((p) {
      if (p.state == AsrJobState.running) {
        context.report(
          AsrStage.transcribing,
          processedMs: p.processedMs,
          totalMs: p.totalMs ?? request.audioMs,
        );
      }
    });
    final result = await job.done;
    await sub.cancel();
    if (!result.succeeded) {
      throw AsrBackendException(
        _error(result.error ?? AsrErrorCode.nativeFailure),
        retryable: result.error?.retryable ?? true,
      );
    }
    final info = engine.info();
    return TranscriptResult(
      raw: result.transcript!,
      backend: kind,
      modelId: s.modelId!,
      modelRevision: s.modelRevision!,
      engineVersion: '${info.engine} ${info.engineVersion}',
    );
  }
}
