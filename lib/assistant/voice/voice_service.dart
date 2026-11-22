import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'voice_settings.dart';

class VoiceFailure implements Exception {
  const VoiceFailure(this.code);
  final String code;
}

abstract interface class VoiceRecorder {
  bool get supported;

  /// Normalized input level (0 silent .. 1 loud), emitted while recording.
  Stream<double> get levels;
  Future<void> start();
  Future<Uint8List> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class DeviceVoiceRecorder implements VoiceRecorder {
  AudioRecorder? _recorder;
  Directory? _directory;
  StreamSubscription<Amplitude>? _amplitude;
  final _levels = StreamController<double>.broadcast();
  @override
  Stream<double> get levels => _levels.stream;

  /// Maps dBFS (about -60 silence .. 0 clipping) onto 0..1.
  static double level(double dbfs) =>
      dbfs.isFinite ? ((dbfs + 50) / 45).clamp(0.0, 1.0) : 0;
  @override
  bool get supported =>
      !kIsWeb &&
      (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows);

  @override
  Future<void> start() async {
    if (!supported) throw const VoiceFailure('unsupported');
    final recorder = _recorder ??= AudioRecorder();
    if (!await recorder.hasPermission()) throw const VoiceFailure('permission');
    if (!await recorder.isEncoderSupported(AudioEncoder.wav)) {
      throw const VoiceFailure('unsupported');
    }
    _directory = await (await getTemporaryDirectory()).createTemp('voice-');
    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: '${_directory!.path}/voice.wav',
    );
    await _amplitude?.cancel();
    _amplitude = recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((a) => _levels.add(level(a.current)), onError: (_) {});
  }

  @override
  Future<Uint8List> stop() async {
    final directory = _directory;
    _directory = null;
    await _amplitude?.cancel();
    _amplitude = null;
    try {
      final path = await _recorder!.stop();
      if (path == null) throw const VoiceFailure('empty');
      final file = File(path);
      final size = await file.length();
      if (size <= 44) throw const VoiceFailure('empty');
      if (size > 24 * 1024 * 1024) throw const VoiceFailure('tooLarge');
      return await file.readAsBytes();
    } finally {
      await _clean(directory);
    }
  }

  Future<void> _clean(Directory? directory) async {
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  @override
  Future<void> cancel() async {
    final directory = _directory;
    _directory = null;
    await _amplitude?.cancel();
    _amplitude = null;
    try {
      await _recorder?.cancel();
    } finally {
      await _clean(directory);
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await cancel();
    } finally {
      await _recorder?.dispose();
      await _levels.close();
    }
  }
}

abstract interface class VoiceTranscriber {
  Future<String> transcribe(VoiceConfig config, String key, Uint8List audio);
  void cancel();
}

/// Uses the same OpenAI SDK as the assistant, with separate credentials.
class OpenAiVoiceTranscriber implements VoiceTranscriber {
  OpenAIClient? _client;

  /// Tests the transcription endpoint with one second of generated silence.
  /// No microphone, user recording or persisted settings are involved.
  Future<void> testConnection(VoiceConfig config, String key) async {
    config.validate();
    if (!config.usePlatform && key.trim().isEmpty) {
      throw const VoiceFailure('missingKey');
    }
    final audio = Uint8List(44 + 32000);
    final header = ByteData.sublistView(audio);
    void tag(int offset, String value) =>
        audio.setRange(offset, offset + value.length, value.codeUnits);
    tag(0, 'RIFF');
    header.setUint32(4, audio.length - 8, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(24, 16000, Endian.little);
    header.setUint32(28, 32000, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    tag(36, 'data');
    header.setUint32(40, 32000, Endian.little);
    // Silence can return an empty transcript; a successful response is enough.
    await _request(config, key, audio, timeout: const Duration(seconds: 20));
  }

  @override
  Future<String> transcribe(
    VoiceConfig config,
    String key,
    Uint8List audio,
  ) async {
    final text = await _request(config, key, audio);
    if (text.isEmpty) throw const VoiceFailure('empty');
    return text;
  }

  Future<String> _request(
    VoiceConfig config,
    String key,
    Uint8List audio, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final client = OpenAIClient.withApiKey(
      config.usePlatform ? 'platform' : key,
      baseUrl: config.effectiveEndpoint,
    );
    _client = client;
    try {
      final result = await client.audio.transcriptions
          .create(
            TranscriptionRequest(
              file: audio,
              filename: 'voice.wav',
              model: config.effectiveModel,
            ),
          )
          .timeout(timeout);
      return result.text.trim();
    } on AuthenticationException {
      throw const VoiceFailure('authentication');
    } on PermissionDeniedException {
      throw const VoiceFailure('authentication');
    } on RateLimitException {
      throw const VoiceFailure('rateLimited');
    } on TimeoutException {
      throw const VoiceFailure('timeout');
    } on RequestTimeoutException {
      throw const VoiceFailure('timeout');
    } finally {
      if (identical(_client, client)) _client = null;
      client.close();
    }
  }

  @override
  void cancel() {
    _client?.close();
    _client = null;
  }
}
