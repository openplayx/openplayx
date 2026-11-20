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
  Future<void> start();
  Future<Uint8List> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class DeviceVoiceRecorder implements VoiceRecorder {
  AudioRecorder? _recorder;
  Directory? _directory;
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
  }

  @override
  Future<Uint8List> stop() async {
    final directory = _directory;
    _directory = null;
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
  @override
  Future<String> transcribe(
    VoiceConfig config,
    String key,
    Uint8List audio,
  ) async {
    final client = OpenAIClient.withApiKey(key, baseUrl: config.endpoint);
    _client = client;
    try {
      final result = await client.audio.transcriptions
          .create(
            TranscriptionRequest(
              file: audio,
              filename: 'voice.wav',
              model: config.model,
            ),
          )
          .timeout(const Duration(seconds: 90));
      if (result.text.trim().isEmpty) throw const VoiceFailure('empty');
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
