import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:openplayx_whisper/openplayx_whisper.dart';

import '../../core/capabilities/speech_recognition_capability.dart';
import 'asr_backend_config.dart';

/// One bounded audio chunk. Scheduling, checkpoints and media offsets belong
/// to SubtitleGenerationService, never to the platform proxy.
class OpenAiAsrBackend implements SpeechRecognitionModelCapability {
  OpenAiAsrBackend({
    required this.config,
    required this.token,
    HttpClient Function()? client,
  }) : _client = client ?? HttpClient.new;
  final AsrBackendConfig config;
  final Future<String?> Function() token;
  final HttpClient Function() _client;
  @override
  String get instanceId => config.id;
  @override
  String get kind => config.kind;
  @override
  Future<AsrBackendStatus> status() async => AsrBackendStatus(
    available: true,
    modelId: config.modelId,
    modelRevision: 'openai-segments-v1',
    engineVersion: 'OpenAI-compatible ASR',
    limits: const {'max_audio_ms': 304000, 'timestamp_level': 'segment'},
  );

  @override
  Future<TranscriptResult> transcribe(
    TranscriptionRequest input,
    AsrTaskContext context,
  ) async {
    if (config.uploads &&
        config.kind != 'platform' &&
        config.uploadConsentAt == null) {
      throw const AsrBackendException('upload_not_authorized');
    }
    if (input.audioMs > 304000) {
      throw const AsrBackendException('audio_too_long');
    }
    for (var attempt = 0; ; attempt++) {
      if (context.cancel.cancelled) {
        throw const AsrBackendException('cancelled');
      }
      try {
        return await _send(input, context);
      } on _RateLimited catch (e) {
        if (attempt >= 2) {
          throw const AsrBackendException('backend_busy', retryable: true);
        }
        final wait = Completer<void>();
        final timer = Timer(e.delay, () {
          if (!wait.isCompleted) wait.complete();
        });
        context.cancel.onCancel(() {
          if (!wait.isCompleted) wait.complete();
        });
        context.report(AsrStage.queued);
        await wait.future;
        timer.cancel();
      }
    }
  }

  Future<TranscriptResult> _send(
    TranscriptionRequest input,
    AsrTaskContext context,
  ) async {
    final client = _client()..connectionTimeout = const Duration(seconds: 20);
    context.cancel.onCancel(() => client.close(force: true));
    try {
      final base = config.url!.replaceFirst(RegExp(r'/+$'), '');
      final uri = Uri.parse(
        config.kind == 'platform' ? base : '$base/audio/transcriptions',
      );
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 20));
      final secret = await token();
      if (context.cancel.cancelled) {
        throw const AsrBackendException('cancelled');
      }
      if (secret != null && secret.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $secret');
      }
      final boundary = 'opx-${DateTime.now().microsecondsSinceEpoch}';
      final fields = {
        'model': config.modelId,
        'response_format': 'verbose_json',
        'timestamp_granularities[]': 'segment',
        'temperature': '0',
        if (input.language != 'auto') 'language': input.language,
      };
      final head = utf8.encode(
        '${fields.entries.map((e) => '--$boundary\r\nContent-Disposition: form-data; name="${e.key}"\r\n\r\n${e.value}\r\n').join()}--$boundary\r\nContent-Disposition: form-data; name="file"; filename="audio.wav"\r\nContent-Type: audio/wav\r\n\r\n',
      );
      final tail = utf8.encode('\r\n--$boundary--\r\n');
      final file = File(input.audioPath);
      final size = await file.length();
      if (size > 24 * 1024 * 1024) {
        throw const AsrBackendException('upload_too_large');
      }
      request.headers.set(
        'Content-Type',
        'multipart/form-data; boundary=$boundary',
      );
      request.contentLength = head.length + size + tail.length;
      request.add(head);
      context.report(AsrStage.uploading, processedMs: 0, totalMs: size);
      var sent = 0;
      await request
          .addStream(
            file.openRead().map((bytes) {
              sent += bytes.length;
              context.report(
                AsrStage.uploading,
                processedMs: sent,
                totalMs: size,
              );
              return bytes;
            }),
          )
          .timeout(const Duration(seconds: 90));
      request.add(tail);
      context.report(AsrStage.transcribing);
      final response = await request.close().timeout(
        const Duration(seconds: 100),
      );
      if (response.statusCode == 429) {
        final seconds =
            int.tryParse(response.headers.value('Retry-After') ?? '') ?? 60;
        if (seconds > 120) {
          throw const AsrBackendException('platform_quota_exceeded');
        }
        throw _RateLimited(Duration(seconds: seconds.clamp(1, 120)));
      }
      if (response.statusCode != 200) {
        throw AsrBackendException(switch (response.statusCode) {
          401 || 403 => 'backend_unauthorized',
          413 => 'upload_too_large',
          400 || 422 => 'backend_rejected',
          503 => 'backend_unavailable',
          _ => 'backend_error',
        }, retryable: response.statusCode >= 500);
      }
      final bytes = <int>[];
      await for (final part in response.timeout(const Duration(seconds: 30))) {
        if (bytes.length + part.length > 4 * 1024 * 1024) {
          throw const FormatException('response_too_large');
        }
        bytes.addAll(part);
      }
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (json['text'] is! String || json['segments'] is! List) {
        throw const FormatException('segments');
      }
      final segments = <RawSegment>[];
      for (final item in json['segments'] as List) {
        final s = item as Map;
        final a = (s['start'] as num).toDouble(),
            b = (s['end'] as num).toDouble();
        if (!a.isFinite ||
            !b.isFinite ||
            a < 0 ||
            b < a ||
            s['text'] is! String ||
            a * 1000 > input.audioMs + 1000) {
          throw const FormatException('segment');
        }
        segments.add(
          RawSegment(
            (a * 1000).round(),
            (b * 1000).round().clamp(0, input.audioMs),
            s['text'] as String,
            (s['no_speech_prob'] as num?)?.toDouble() ?? 0,
          ),
        );
      }
      if (context.cancel.cancelled) {
        throw const AsrBackendException('cancelled');
      }
      return TranscriptResult(
        raw: RawTranscript(
          language: json['language'] as String? ?? input.language,
          audioMs: input.audioMs,
          windowMs: input.audioMs,
          overlapMs: 0,
          windows: [RawWindow(0, input.audioMs, segments)],
        ),
        backend: kind,
        modelId: config.modelId,
        modelRevision: 'openai-segments-v1',
        engineVersion: 'OpenAI-compatible ASR',
      );
    } on _RateLimited {
      rethrow;
    } on AsrBackendException {
      rethrow;
    } catch (e) {
      if (context.cancel.cancelled) {
        throw const AsrBackendException('cancelled');
      }
      if (e is TimeoutException) {
        throw const AsrBackendException('backend_timeout', retryable: true);
      }
      if (e is HandshakeException) {
        throw const AsrBackendException('tls_verification_failed');
      }
      if (e is SocketException || e is HttpException) {
        throw const AsrBackendException('backend_unreachable', retryable: true);
      }
      throw const AsrBackendException('result_invalid');
    } finally {
      client.close(force: true);
    }
  }
}

class _RateLimited implements Exception {
  const _RateLimited(this.delay);
  final Duration delay;
}
