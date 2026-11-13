import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../core/plugins/speech_recognition_capability.dart';
import 'asr_backend_config.dart';

/// Client for the project's own recognition service API
/// (`/v1/transcription-jobs`, see openplayx-asr/openapi.yaml). The service
/// receives only the normalised audio the app extracted: never a video URL,
/// NAS credential or local path. Times come back as `audio_ms`.
class HttpAsrBackend implements SpeechRecognitionModelCapability {
  HttpAsrBackend({
    required this.config,
    required this.token,
    HttpClient Function()? client,
    this.pollMin = const Duration(seconds: 1),
    this.pollMax = const Duration(seconds: 8),
    this.requestTimeout = const Duration(seconds: 20),
  }) : _client = client ?? HttpClient.new;

  final AsrBackendConfig config;
  final Future<String?> Function() token;
  final HttpClient Function() _client;
  final Duration pollMin, pollMax, requestTimeout;

  @override
  String get instanceId => config.id;
  @override
  String get kind => 'http';

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(config.url!);
    final prefix = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(path: '$prefix$path', queryParameters: query);
  }

  /// Sends one request; returns (status, decoded JSON or null).
  Future<(int, Map<String, dynamic>?)> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, String> headers = const {},
    File? body,
    void Function(int sent)? onSent,
  }) async {
    final secret = await token();
    final client = _client()..connectionTimeout = requestTimeout;
    // Certificates are always verified; badCertificateCallback is never set.
    try {
      final request = await client
          .openUrl(method, _uri(path, query))
          .timeout(requestTimeout);
      if (secret != null && secret.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $secret');
      }
      headers.forEach(request.headers.set);
      if (body != null) {
        request.headers.contentType = ContentType('audio', 'wav');
        request.contentLength = await body.length();
        var sent = 0;
        await request.addStream(
          body.openRead().map((chunk) {
            sent += chunk.length;
            onSent?.call(sent);
            return chunk;
          }),
        );
      }
      final response = await request.close().timeout(
        body == null ? requestTimeout : const Duration(minutes: 10),
      );
      final text = await utf8.decodeStream(response).timeout(requestTimeout);
      Map<String, dynamic>? json;
      if (text.isNotEmpty) {
        try {
          json = jsonDecode(text) as Map<String, dynamic>;
        } catch (_) {}
      }
      return (response.statusCode, json);
    } on TimeoutException {
      throw const AsrBackendException('backend_timeout', retryable: true);
    } on HandshakeException {
      throw const AsrBackendException('tls_verification_failed');
    } on SocketException {
      throw const AsrBackendException('backend_unreachable', retryable: true);
    } on HttpException {
      throw const AsrBackendException('backend_unreachable', retryable: true);
    } finally {
      client.close(force: true);
    }
  }

  static AsrBackendException _fail(int status, Map<String, dynamic>? json) {
    final code = (json?['error'] as Map?)?['code'] as String?;
    return switch (status) {
      401 || 403 => const AsrBackendException('backend_unauthorized'),
      404 => AsrBackendException(code ?? 'not_found'),
      413 => const AsrBackendException('upload_too_large'),
      429 ||
      503 => AsrBackendException(code ?? 'backend_busy', retryable: true),
      _ when status >= 500 => const AsrBackendException(
        'backend_error',
        retryable: true,
      ),
      _ => AsrBackendException(code ?? 'backend_rejected'),
    };
  }

  Map<String, dynamic>? _capabilities;

  Future<Map<String, dynamic>> capabilities() async {
    final (status, json) = await _send('GET', '/v1/capabilities');
    if (status != 200 || json == null) throw _fail(status, json);
    return _capabilities = json;
  }

  @override
  Future<AsrBackendStatus> status() async {
    try {
      final caps = await capabilities();
      final models = [
        for (final m in caps['models'] as List? ?? const []) m as Map,
      ];
      final model = models.where((m) => m['id'] == config.modelId).firstOrNull;
      return AsrBackendStatus(
        available: model != null,
        reason: model == null ? 'model_not_on_service' : null,
        modelId: config.modelId,
        modelRevision: model?['revision'] as String?,
        engineVersion: '${caps['engine']} ${caps['engine_version']}',
        limits: (caps['limits'] as Map?)?.cast<String, Object?>() ?? const {},
      );
    } on AsrBackendException catch (e) {
      return AsrBackendStatus(
        available: false,
        reason: e.code,
        modelId: config.modelId,
      );
    }
  }

  /// Stable per (instance, audio, model, language): a retried upload maps to
  /// the job the service may already have created.
  String idempotencyKey(TranscriptionRequest r) => sha256
      .convert(
        utf8.encode(
          '${config.id}|${r.audioSha256}|${config.modelId}|${r.language}',
        ),
      )
      .toString();

  Future<Map<String, dynamic>?> _findByKey(String key) async {
    final (status, json) = await _send(
      'GET',
      '/v1/transcription-jobs',
      query: {'idempotency_key': key},
    );
    if (status == 404) return null;
    if (status != 200 || json == null) throw _fail(status, json);
    final jobs = json['jobs'] as List? ?? const [];
    return jobs.isEmpty ? null : jobs.first as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _create(
    TranscriptionRequest r,
    String key,
    AsrTaskContext context,
  ) async {
    final file = File(r.audioPath);
    final size = await file.length();
    final limit =
        (_capabilities?['limits'] as Map?)?['max_upload_bytes'] as int?;
    if (limit != null && size > limit) {
      throw const AsrBackendException('upload_too_large');
    }
    var delay = const Duration(seconds: 1);
    for (var attempt = 0; ; attempt++) {
      if (context.cancel.cancelled) {
        throw const AsrBackendException('cancelled');
      }
      // Before (re)sending, check whether an earlier attempt got through.
      final existing = await _findByKey(key);
      if (existing != null &&
          existing['status'] != 'cancelled' &&
          existing['status'] != 'failed') {
        return existing;
      }
      try {
        context.report(AsrStage.uploading, processedMs: 0, totalMs: size);
        final (status, json) = await _send(
          'POST',
          '/v1/transcription-jobs',
          query: {'model': config.modelId, 'language': r.language},
          headers: {'Idempotency-Key': key, 'X-Content-SHA256': r.audioSha256},
          body: file,
          onSent: (sent) => context.report(
            AsrStage.uploading,
            processedMs: sent,
            totalMs: size,
          ),
        );
        if ((status == 202 || status == 200) && json != null) return json;
        throw _fail(status, json);
      } on AsrBackendException catch (e) {
        if (!e.retryable || attempt >= 2) rethrow;
        await Future<void>.delayed(delay);
        delay *= 2;
      }
    }
  }

  @override
  Future<TranscriptResult> transcribe(
    TranscriptionRequest request,
    AsrTaskContext context,
  ) async {
    final caps = _capabilities ?? await capabilities();
    final model = [
      for (final m in caps['models'] as List? ?? const []) m as Map,
    ].where((m) => m['id'] == config.modelId).firstOrNull;
    if (model == null) throw const AsrBackendException('model_not_on_service');
    final maxMs = (caps['limits'] as Map?)?['max_audio_ms'] as int?;
    if (maxMs != null && request.audioMs > maxMs) {
      throw const AsrBackendException('audio_too_long');
    }
    final key = idempotencyKey(request);
    var job = await _create(request, key, context);
    final id = job['id'] as String;
    context.remoteJob?.call(id);
    var cancelSent = false;
    context.cancel.onCancel(() {
      if (cancelSent) return;
      cancelSent = true;
      unawaited(cancelRemote(id).catchError((_) => false));
    });
    var delay = pollMin;
    var failures = 0;
    while (true) {
      if (context.cancel.cancelled) {
        throw const AsrBackendException('cancelled');
      }
      final state = job['status'] as String?;
      switch (state) {
        case 'succeeded':
          final (status, json) = await _send(
            'GET',
            '/v1/transcription-jobs/$id/result',
          );
          if (context.cancel.cancelled) {
            throw const AsrBackendException('cancelled');
          }
          if (status != 200 || json == null) throw _fail(status, json);
          if (json['timebase'] != 'audio_ms') {
            throw const AsrBackendException('result_invalid');
          }
          return TranscriptResult(
            raw: RawTranscript.fromJson(json),
            backend: kind,
            modelId: json['model_id'] as String? ?? config.modelId,
            modelRevision: json['model_revision'] as String? ?? '',
            engineVersion:
                '${json['engine'] ?? ''} ${json['engine_version'] ?? ''}'
                    .trim(),
            remoteJobId: id,
          );
        case 'failed':
          throw AsrBackendException(
            ((job['error'] as Map?)?['code'] as String?) ??
                'recognition_failed',
            retryable: true,
          );
        case 'cancelled':
          throw const AsrBackendException('cancelled');
        case 'queued':
          context.report(AsrStage.queued);
        default:
          context.report(
            AsrStage.transcribing,
            processedMs: job['processed_ms'] as int? ?? 0,
            totalMs: job['audio_ms'] as int? ?? request.audioMs,
          );
      }
      await Future<void>.delayed(delay);
      if (delay < pollMax) delay *= 2;
      try {
        final (status, json) = await _send('GET', '/v1/transcription-jobs/$id');
        if (status != 200 || json == null) throw _fail(status, json);
        job = json;
        failures = 0;
      } on AsrBackendException catch (e) {
        // Brief disconnects keep the remote job; give up after a few tries.
        if (!e.retryable || ++failures > 5) rethrow;
      }
    }
  }

  /// Idempotent cancel request; the job is only cancelled once it stops.
  Future<bool> cancelRemote(String id) async {
    final (status, _) = await _send(
      'POST',
      '/v1/transcription-jobs/$id/cancel',
    );
    return status == 200 || status == 202 || status == 404;
  }

  /// Deletes a terminal job with its input and output. False when it could
  /// not be confirmed (the host keeps it marked as pending cleanup).
  Future<bool> deleteRemote(String id) async {
    try {
      final (status, _) = await _send('DELETE', '/v1/transcription-jobs/$id');
      return status == 204 || status == 404;
    } on AsrBackendException {
      return false;
    }
  }
}
