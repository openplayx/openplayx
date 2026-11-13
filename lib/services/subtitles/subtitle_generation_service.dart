import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/plugins/source_capability.dart';
import '../../core/plugins/speech_recognition_capability.dart';
import '../media_processing/media_processing_service.dart';
import 'asr_backend_config.dart';
import 'http_asr_backend.dart';
import 'subtitle_format.dart';
import 'transcript.dart';

/// One audio track of a resource, addressed by a host-issued reference that
/// also fingerprints the stream: a changed file never reuses an old index.
class AudioTrackChoice {
  const AudioTrackChoice({
    required this.ref,
    required this.index,
    required this.codec,
    required this.language,
    required this.title,
    required this.channels,
    required this.sampleRate,
    required this.isDefault,
    required this.decodable,
  });
  final String ref;
  final int index;
  final String codec, language, title;
  final int channels, sampleRate;
  final bool isDefault, decodable;
}

class ResourceAudioInfo {
  const ResourceAudioInfo({
    required this.durationMs,
    required this.tracks,
    required this.fingerprint,
  });

  /// Null when the container does not report a duration.
  final int? durationMs;
  final List<AudioTrackChoice> tracks;
  final String fingerprint;
  AudioTrackChoice? get defaultTrack =>
      tracks.where((t) => t.isDefault).firstOrNull ?? tracks.firstOrNull;
}

/// Who asked: the debug page or an AI tool. Established by the host only.
enum SubtitleCaller { debug, ai }

class SubtitleRequest {
  const SubtitleRequest({
    required this.resource,
    required this.resourceName,
    required this.caller,
    this.trackRef,
    this.startMs = 0,
    this.endMs,
    this.wholeMedia = false,
    this.backendId,
    this.language,
    this.transcribe = true,
    this.subtitleOutput = true,
  });
  final ResourceRef resource;
  final String resourceName;
  final SubtitleCaller caller;
  final String? trackRef;
  final int startMs;

  /// Exclusive end on the media timeline; required unless [wholeMedia].
  final int? endMs;
  final bool wholeMedia;
  final String? backendId;
  final String? language;

  /// False: "extract audio only" (no model load, no upload).
  final bool transcribe;

  /// AI `transcript_generate` publishes only the transcript artifact.
  final bool subtitleOutput;
}

class AudioResult {
  const AudioResult({
    required this.artifactId,
    required this.trackIndex,
    required this.sampleRate,
    required this.channels,
    required this.durationMs,
    required this.bytes,
    required this.reused,
  });
  final String artifactId;
  final int trackIndex, sampleRate, channels, durationMs, bytes;
  final bool reused;
}

enum SubtitleRunStatus {
  running,
  succeeded,
  failed,
  cancelling,
  cancelled,
  interrupted;

  bool get terminal => this != running && this != cancelling;
}

class SubtitleRunState {
  const SubtitleRunState({
    required this.taskId,
    required this.status,
    this.stage = AsrStage.preparing,
    this.processed,
    this.total,
    this.error,
    this.stageMs = const {},
    this.audio,
    this.transcript,
    this.cues,
    this.backend,
    this.modelId,
    this.engineVersion,
    this.remoteJobId,
  });
  final String taskId;
  final SubtitleRunStatus status;
  final AsrStage stage;

  /// Stage-local progress; null when the amount of work is unknown.
  final int? processed, total;
  final String? error;
  final Map<String, int> stageMs;
  final AudioResult? audio;
  final Transcript? transcript;
  final List<SubtitleCue>? cues;
  final String? backend, modelId, engineVersion, remoteJobId;

  SubtitleRunState copyWith({
    SubtitleRunStatus? status,
    AsrStage? stage,
    int? processed,
    int? total,
    bool clearProgress = false,
    String? error,
    Map<String, int>? stageMs,
    AudioResult? audio,
    Transcript? transcript,
    List<SubtitleCue>? cues,
    String? backend,
    String? modelId,
    String? engineVersion,
    String? remoteJobId,
  }) => SubtitleRunState(
    taskId: taskId,
    status: status ?? this.status,
    stage: stage ?? this.stage,
    processed: clearProgress ? null : processed ?? this.processed,
    total: clearProgress ? null : total ?? this.total,
    error: error ?? this.error,
    stageMs: stageMs ?? this.stageMs,
    audio: audio ?? this.audio,
    transcript: transcript ?? this.transcript,
    cues: cues ?? this.cues,
    backend: backend ?? this.backend,
    modelId: modelId ?? this.modelId,
    engineVersion: engineVersion ?? this.engineVersion,
    remoteJobId: remoteJobId ?? this.remoteJobId,
  );
}

class SubtitleException implements Exception {
  const SubtitleException(this.code, {this.retryable = false});
  final String code;
  final bool retryable;
  @override
  String toString() => 'SubtitleException($code)';
}

/// A live workflow. Its stream closes when the run ends or the handle is
/// detached (a closed debug page receives no late events).
class SubtitleRun {
  SubtitleRun._(this.taskId, SubtitleRunState initial) : _state = initial;
  final String taskId;
  final _updates = StreamController<SubtitleRunState>.broadcast();
  final _done = Completer<SubtitleRunState>();
  final cancelToken = AsrCancelToken();
  SubtitleRunState _state;

  SubtitleRunState get current => _state;
  Stream<SubtitleRunState> get updates => _updates.stream;
  Future<SubtitleRunState> get done => _done.future;

  void cancel() {
    if (_state.status.terminal || cancelToken.cancelled) return;
    _emit(_state.copyWith(status: SubtitleRunStatus.cancelling));
    cancelToken.cancel();
  }

  void _emit(SubtitleRunState s) {
    _state = s;
    if (!_updates.isClosed) _updates.add(s);
    if (s.status.terminal && !_done.isCompleted) {
      _done.complete(s);
      unawaited(_updates.close());
    }
  }
}

/// Audio extraction → recognition → subtitles workflow (design §2, §4, §8).
///
/// Extraction reuses the media processing task/artifact system (a child
/// `processing_tasks` row with the `audio.speech.wav` preset); this service
/// keeps the parent task, the transcript and subtitle outputs and explicit
/// saves/bindings. It never binds, replaces or loads subtitles by itself.
class SubtitleGenerationService {
  SubtitleGenerationService({
    required this.db,
    required this.media,
    required this.backends,
    required this.root,
  }) {
    db.execute('''CREATE TABLE IF NOT EXISTS transcription_tasks (
      id TEXT PRIMARY KEY, caller TEXT NOT NULL, transcribe INTEGER NOT NULL,
      resource_source TEXT NOT NULL, resource_item TEXT NOT NULL,
      resource_name TEXT NOT NULL, fingerprint TEXT, track_ref TEXT,
      track_index INTEGER, range_start_ms INTEGER NOT NULL, range_end_ms INTEGER,
      whole INTEGER NOT NULL DEFAULT 0, backend_id TEXT, backend_kind TEXT,
      model_id TEXT, model_revision TEXT, engine_version TEXT, language TEXT,
      state TEXT NOT NULL, stage TEXT, error TEXT, stage_ms TEXT,
      extract_task_id TEXT, audio_artifact_id TEXT, audio_sha256 TEXT,
      audio_owned INTEGER NOT NULL DEFAULT 0, remote_job_id TEXT,
      remote_cleanup TEXT, transcript_path TEXT, cache_key TEXT, request_key TEXT,
      transcript_artifact_id TEXT, subtitle_artifact_id TEXT,
      created INTEGER NOT NULL, updated INTEGER NOT NULL)''');
    db.execute('''CREATE TABLE IF NOT EXISTS subtitle_bindings (
      id TEXT PRIMARY KEY, task_id TEXT NOT NULL, subtitle_artifact_id TEXT NOT NULL,
      transcript_artifact_id TEXT, resource_source TEXT NOT NULL,
      resource_item TEXT NOT NULL, fingerprint TEXT, track_index INTEGER,
      range_start_ms INTEGER NOT NULL, range_end_ms INTEGER NOT NULL,
      partial INTEGER NOT NULL, language TEXT, backend TEXT, model_id TEXT,
      model_revision TEXT, preset_revision INTEGER, format TEXT NOT NULL,
      created INTEGER NOT NULL)''');
  }

  static SubtitleGenerationService? current;

  static Future<Directory?> defaultRoot() async {
    try {
      final base = await getApplicationSupportDirectory();
      return Directory('${base.path}/subtitles');
    } catch (_) {
      return null;
    }
  }

  /// Default debug range (design §3.2).
  static const defaultRangeMs = 60000;

  /// 16 kHz × 16-bit mono.
  static int estimateWavBytes(int ms) => 44 + ms * 32;

  final Database db;
  final MediaProcessingService media;
  final AsrBackendRegistry backends;
  final Future<Directory?> root;
  final _runs = <String, SubtitleRun>{};
  final _changes = StreamController<String>.broadcast();
  Stream<String> get changes => _changes.stream;

  static int get _now => DateTime.now().millisecondsSinceEpoch;
  static String _id(String prefix) {
    final r = Random.secure();
    return '$prefix-${List.generate(12, (_) => r.nextInt(16).toRadixString(16)).join()}';
  }

  Future<Directory> _dir(String name) async {
    final base = await root;
    if (base == null) throw const SubtitleException('storage_unavailable');
    return Directory('${base.path}/$name').create(recursive: true);
  }

  void _update(String id, Map<String, Object?> values) {
    final keys = values.keys.toList();
    db.execute(
      'UPDATE transcription_tasks SET ${keys.map((k) => '$k=?').join(',')},updated=? WHERE id=?',
      [...keys.map((k) => values[k]), _now, id],
    );
    if (!_changes.isClosed) _changes.add(id);
  }

  // ------------------------------------------------------------- inspect

  static String _trackRef(MediaStreamInfo s) {
    final h = sha1
        .convert(
          utf8.encode('${s.codec}|${s.language}|${s.channels}|${s.sampleRate}'),
        )
        .toString()
        .substring(0, 8);
    return 'track:${s.index}:$h';
  }

  static String _fingerprint(MediaProbe p) => sha1
      .convert(
        utf8.encode(
          [
            p.container,
            p.durationUs,
            p.bitRate,
            for (final s in p.streams) '${s.index}/${s.type}/${s.codec}',
          ].join('|'),
        ),
      )
      .toString();

  static ResourceAudioInfo _info(MediaProbe p) => ResourceAudioInfo(
    durationMs: p.duration?.inMilliseconds,
    fingerprint: _fingerprint(p),
    tracks: [
      for (final s in p.audio)
        AudioTrackChoice(
          ref: _trackRef(s),
          index: s.index,
          codec: s.codec,
          language: s.language,
          title: s.title,
          channels: s.channels,
          sampleRate: s.sampleRate,
          isDefault: s == p.primaryAudio,
          decodable: s.decodable,
        ),
    ],
  );

  /// Reads only what the page needs: duration and audio tracks. No model
  /// load, upload or recognition.
  Future<ResourceAudioInfo> inspect(ResourceRef ref) async {
    try {
      return _info(await media.probe(ref));
    } on MediaException catch (e) {
      throw SubtitleException(_mediaCode(e), retryable: e.code.retryable);
    }
  }

  static String _mediaCode(MediaException e) => switch (e.code) {
    MediaErrorCode.unavailable => 'ffmpeg_unavailable',
    MediaErrorCode.inputUnavailable => 'resource_unavailable',
    MediaErrorCode.accessDenied => e.reason ?? 'access_denied',
    MediaErrorCode.cancelled => 'cancelled',
    MediaErrorCode.noSpace => 'no_space',
    _ => e.reason ?? e.code.name,
  };

  // --------------------------------------------------------------- start

  /// Active run with the same configuration, so repeated clicks never start
  /// two tasks.
  SubtitleRun? _activeFor(String key) {
    for (final run in _runs.values) {
      final rows = db.select(
        'SELECT request_key FROM transcription_tasks WHERE id=?',
        [run.taskId],
      );
      if (rows.isNotEmpty &&
          rows.first['request_key'] == key &&
          !run.current.status.terminal) {
        return run;
      }
    }
    return null;
  }

  SubtitleRun start(SubtitleRequest r) {
    if (r.startMs < 0 ||
        (!r.wholeMedia && (r.endMs == null || r.endMs! <= r.startMs))) {
      throw const SubtitleException('invalid_range');
    }
    if (r.transcribe) {
      final config = backends.get(r.backendId ?? '');
      if (config == null) {
        throw const SubtitleException('backend_not_configured');
      }
      if (config.uploads && config.uploadConsentAt == null) {
        throw const SubtitleException('upload_not_authorized');
      }
    }
    final key = [
      r.resource.instanceId,
      r.resource.id,
      r.trackRef,
      r.wholeMedia ? 'whole' : '${r.startMs}-${r.endMs}',
      r.transcribe ? '${r.backendId}|${r.language}' : 'audio',
    ].join('|');
    final active = _activeFor(key);
    if (active != null) return active;
    final id = _id('subtitle');
    final config = r.transcribe ? backends.get(r.backendId!) : null;
    db.execute(
      '''INSERT INTO transcription_tasks (id,caller,transcribe,resource_source,
         resource_item,resource_name,track_ref,range_start_ms,range_end_ms,whole,
         backend_id,backend_kind,model_id,language,state,stage,request_key,created,updated)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
      [
        id,
        r.caller.name,
        r.transcribe ? 1 : 0,
        r.resource.instanceId,
        r.resource.id,
        r.resourceName,
        r.trackRef,
        r.startMs,
        r.endMs,
        r.wholeMedia ? 1 : 0,
        config?.id,
        config?.kind,
        config?.modelId,
        r.language ?? config?.language,
        'running',
        AsrStage.preparing.name,
        key,
        _now,
        _now,
      ],
    );
    final run = _runs[id] = SubtitleRun._(
      id,
      SubtitleRunState(taskId: id, status: SubtitleRunStatus.running),
    );
    unawaited(_execute(run, r, config));
    return run;
  }

  Future<void> _execute(
    SubtitleRun run,
    SubtitleRequest r,
    AsrBackendConfig? config,
  ) async {
    final id = run.taskId;
    final stageMs = <String, int>{};
    var stage = AsrStage.preparing;
    var stageStart = _now;
    void enter(AsrStage next, {int? processed, int? total}) {
      if (next != stage) {
        stageMs[stage.name] = (stageMs[stage.name] ?? 0) + _now - stageStart;
        stage = next;
        stageStart = _now;
        _update(id, {'stage': next.name, 'stage_ms': jsonEncode(stageMs)});
      }
      run._emit(
        run.current.copyWith(
          stage: next,
          processed: processed,
          total: total,
          clearProgress: processed == null && total == null,
          stageMs: Map.of(stageMs),
        ),
      );
    }

    void check() {
      if (run.cancelToken.cancelled) throw const SubtitleException('cancelled');
    }

    try {
      // 1. Resource, tracks and range.
      enter(AsrStage.preparing);
      final info = await inspect(r.resource);
      check();
      final track = r.trackRef == null
          ? info.defaultTrack
          : info.tracks.where((t) => t.ref == r.trackRef).firstOrNull;
      if (info.tracks.isEmpty) throw const SubtitleException('no_audio_track');
      if (track == null) throw const SubtitleException('audio_track_changed');
      if (!track.decodable) {
        throw const SubtitleException('audio_not_decodable');
      }
      final duration = info.durationMs;
      int start = r.startMs;
      int end;
      if (r.wholeMedia) {
        if (duration == null) throw const SubtitleException('duration_unknown');
        start = 0;
        end = duration;
      } else {
        end = r.endMs!;
        if (duration != null) {
          if (start >= duration) {
            throw const SubtitleException('range_outside_media');
          }
          end = min(end, duration);
        }
      }
      _update(id, {
        'fingerprint': info.fingerprint,
        'track_ref': track.ref,
        'track_index': track.index,
        'range_start_ms': start,
        'range_end_ms': end,
      });

      // 2. Extraction (reused when an identical, still valid result exists).
      enter(AsrStage.extracting);
      final audio = await _extract(run, r, info, track, start, end, (p, t) {
        enter(AsrStage.extracting, processed: p, total: t);
      });
      run._emit(run.current.copyWith(audio: audio));
      check();
      if (!r.transcribe) {
        _finish(run, stageMs, stage, stageStart, SubtitleRunStatus.succeeded);
        return;
      }

      // 3. Recognition.
      final path = media.artifactPath(audio.artifactId);
      if (path == null) throw const SubtitleException('audio_unavailable');
      final sha = (await sha256.bind(File(path).openRead()).first).toString();
      _update(id, {'audio_sha256': sha});
      final backend = backends.backend(config!.id);
      final status = await backend.status();
      check();
      if (!status.available) {
        throw SubtitleException(status.reason ?? 'backend_unavailable');
      }
      final language = r.language ?? config.language;
      final cacheKey = sha256
          .convert(
            utf8.encode(
              [
                sha,
                config.kind,
                status.modelId,
                status.modelRevision,
                language,
                start,
              ].join('|'),
            ),
          )
          .toString();
      TranscriptResult? result;
      Transcript? cached = _cachedTranscript(cacheKey);
      if (cached == null) {
        result = await backend.transcribe(
          TranscriptionRequest(
            audioPath: path,
            audioMs: audio.durationMs,
            audioSha256: sha,
            language: language,
          ),
          AsrTaskContext(
            cancel: run.cancelToken,
            report: (s, {processedMs, totalMs}) =>
                enter(s, processed: processedMs, total: totalMs),
            remoteJob: (remote) {
              _update(id, {'remote_job_id': remote});
              run._emit(run.current.copyWith(remoteJobId: remote));
            },
          ),
        );
        check();
      }

      // 4. Merge, map to media time, validate, build cues.
      enter(AsrStage.formatting);
      final transcript =
          cached ??
          Transcript(
            resourceRef: '${r.resource.instanceId}:${r.resource.id}',
            audioTrackRef: track.ref,
            rangeStartMs: start,
            rangeEndMs: end,
            wholeMedia: r.wholeMedia,
            language: result!.raw.language,
            backend: result.backend,
            modelId: result.modelId,
            modelRevision: result.modelRevision,
            engineVersion: result.engineVersion,
            parameters: {
              'audio_preset': MediaPreset.speechWav.id,
              'audio_preset_revision': MediaPreset.speechWav.revision,
              'window_ms': result.raw.windowMs,
              'overlap_ms': result.raw.overlapMs,
              'requested_language': language,
              'fingerprint': info.fingerprint,
            },
            segments: toMediaTime(
              mergeWindows(result.raw),
              start,
              rangeEndMs: end,
            ),
          );
      try {
        validateSegments(transcript.segments, minMs: start, maxMs: end);
      } on FormatException catch (e) {
        throw SubtitleException('transcript_invalid:${e.message}');
      }
      final cues = buildCues(transcript.segments);
      validateCues(cues.where((c) => c.endMs > c.startMs).toList());
      final work = await _dir('work');
      final file = File('${work.path}/$id.transcript.json');
      await file.writeAsString(jsonEncode(transcript.toJson()));
      _update(id, {
        'transcript_path': file.path,
        'cache_key': cacheKey,
        'model_id': transcript.modelId,
        'model_revision': transcript.modelRevision,
        'engine_version': transcript.engineVersion,
        'language': transcript.language,
      });
      run._emit(
        run.current.copyWith(
          transcript: transcript,
          cues: cues,
          backend: transcript.backend,
          modelId: transcript.modelId,
          engineVersion: transcript.engineVersion,
        ),
      );
      if (r.caller == SubtitleCaller.ai) {
        await _publishResult(id, r, transcript);
      }
      _finish(run, stageMs, stage, stageStart, SubtitleRunStatus.succeeded);
      // The app keeps the result; remote input/output are removed now.
      final remote = result?.remoteJobId;
      if (remote != null && backend is HttpAsrBackend) {
        final deleted = await backend.deleteRemote(remote);
        _update(id, {'remote_cleanup': deleted ? 'done' : 'pending'});
      }
    } catch (e) {
      final code = switch (e) {
        SubtitleException(:final code) => code,
        AsrBackendException(:final code) => code,
        MediaException() => _mediaCode(e),
        _ => 'internal_error',
      };
      final cancelled = code == 'cancelled' || run.cancelToken.cancelled;
      _update(id, {'error': cancelled ? 'cancelled' : code});
      run._emit(run.current.copyWith(error: cancelled ? 'cancelled' : code));
      _finish(
        run,
        stageMs,
        stage,
        stageStart,
        cancelled ? SubtitleRunStatus.cancelled : SubtitleRunStatus.failed,
      );
      final remote =
          db.select(
                'SELECT remote_job_id FROM transcription_tasks WHERE id=?',
                [id],
              ).first['remote_job_id']
              as String?;
      if (remote != null && config != null) {
        unawaited(_cleanupRemote(id, config.id, remote));
      }
    }
  }

  /// AI results become unbound artifacts (task → artifact refs); binding to
  /// the resource still needs an explicit save.
  Future<void> _publishResult(
    String id,
    SubtitleRequest r,
    Transcript t,
  ) async {
    final dir = await _dir('saved');
    final base = r.resourceName.replaceAll('\\', '/').split('/').last;
    Future<String> publish(String kind, String ext, String content) async {
      final artifact = _id('artifact');
      final path = '${dir.path}/$artifact.$ext';
      final part = File('$path.part');
      await part.writeAsString(content, flush: true);
      await part.rename(path);
      db.execute('INSERT INTO media_artifacts VALUES (?,?,?,?,?,?,?)', [
        artifact,
        id,
        kind,
        path,
        '$base.${t.language}.asr.$ext',
        await File(path).length(),
        _now,
      ]);
      return artifact;
    }

    _update(id, {
      'transcript_artifact_id': await publish(
        'transcript',
        'json',
        jsonEncode(t.toJson()),
      ),
      if (r.subtitleOutput && t.segments.isNotEmpty)
        'subtitle_artifact_id': await publish(
          'subtitle',
          'srt',
          serialize(buildCues(t.segments), SubtitleFormat.srt),
        ),
    });
  }

  void _finish(
    SubtitleRun run,
    Map<String, int> stageMs,
    AsrStage stage,
    int stageStart,
    SubtitleRunStatus status,
  ) {
    stageMs[stage.name] = (stageMs[stage.name] ?? 0) + _now - stageStart;
    _update(run.taskId, {
      'state': status.name,
      'stage_ms': jsonEncode(stageMs),
    });
    _runs.remove(run.taskId);
    run._emit(run.current.copyWith(status: status, stageMs: Map.of(stageMs)));
  }

  Future<void> _cleanupRemote(
    String taskId,
    String backendId,
    String remote,
  ) async {
    try {
      final backend = backends.backend(backendId);
      if (backend is! HttpAsrBackend) return;
      await backend.cancelRemote(remote).catchError((_) => false);
      // Deletion only succeeds once the job is terminal; retry briefly.
      for (var i = 0; i < 5; i++) {
        if (await backend.deleteRemote(remote)) {
          _update(taskId, {'remote_cleanup': 'done'});
          return;
        }
        await Future<void>.delayed(Duration(seconds: 2 << i));
      }
    } catch (_) {}
    _update(taskId, {'remote_cleanup': 'pending'});
  }

  Transcript? _cachedTranscript(String key) {
    final rows = db.select(
      "SELECT transcript_path FROM transcription_tasks WHERE cache_key=? AND state='succeeded' AND transcript_path IS NOT NULL ORDER BY updated DESC LIMIT 1",
      [key],
    );
    if (rows.isEmpty) return null;
    final f = File(rows.first['transcript_path'] as String);
    if (!f.existsSync()) return null;
    try {
      return Transcript.fromJson(
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<AudioResult> _extract(
    SubtitleRun run,
    SubtitleRequest r,
    ResourceAudioInfo info,
    AudioTrackChoice track,
    int start,
    int end,
    void Function(int? processed, int? total) progress,
  ) async {
    final id = run.taskId;
    // Reuse: same resource fingerprint, track and range, artifact present.
    final reuse = db.select(
      '''SELECT audio_artifact_id FROM transcription_tasks WHERE resource_source=?
         AND resource_item=? AND fingerprint=? AND track_index=? AND range_start_ms=?
         AND range_end_ms=? AND audio_artifact_id IS NOT NULL AND id<>?
         ORDER BY updated DESC''',
      [
        r.resource.instanceId,
        r.resource.id,
        info.fingerprint,
        track.index,
        start,
        end,
        id,
      ],
    );
    for (final row in reuse) {
      final artifact = row['audio_artifact_id'] as String;
      final path = media.artifactPath(artifact);
      if (path != null && File(path).existsSync()) {
        _update(id, {'audio_artifact_id': artifact, 'audio_owned': 0});
        return _describeAudio(artifact, path, track.index, reused: true);
      }
    }
    final Map<String, dynamic> task;
    try {
      task = media.submit(
        ref: r.resource,
        resourceName: r.resourceName,
        presetId: MediaPreset.speechWav.id,
        presetRevision: MediaPreset.speechWav.revision,
        operation: MediaOperation.extractAudio,
        request: PlanRequest(
          start: Duration(milliseconds: start),
          end: Duration(milliseconds: end),
          audioStream: track.index,
        ),
      );
    } on MediaException catch (e) {
      throw SubtitleException(_mediaCode(e));
    }
    final taskId = task['task_id'] as String;
    _update(id, {'extract_task_id': taskId});
    run.cancelToken.onCancel(() {
      try {
        media.cancel(taskId);
      } catch (_) {}
    });
    final finished = Completer<Map<String, dynamic>>();
    void check(String changed) {
      if (changed != taskId || finished.isCompleted) return;
      final t = media.task(taskId);
      if (t == null) return;
      final status = t['status'] as String;
      if (const [
        'succeeded',
        'failed',
        'cancelled',
        'interrupted',
      ].contains(status)) {
        finished.complete(t);
      } else {
        progress(t['processed_ms'] as int?, t['total_ms'] as int?);
      }
    }

    final sub = media.changes.listen(check);
    check(taskId);
    final t = await finished.future;
    await sub.cancel();
    if (t['status'] != 'succeeded') {
      if (t['status'] == 'cancelled' || run.cancelToken.cancelled) {
        throw const SubtitleException('cancelled');
      }
      final reason = t['reason'] as String?;
      throw SubtitleException(
        reason ?? (t['error_code'] as String? ?? 'extract_failed'),
        retryable: t['retryable'] == true,
      );
    }
    final artifact = (t['artifact'] as Map)['artifact_ref'] as String;
    _update(id, {'audio_artifact_id': artifact, 'audio_owned': 1});
    final path = media.artifactPath(artifact);
    if (path == null) throw const SubtitleException('audio_unavailable');
    return _describeAudio(artifact, path, track.index, reused: false);
  }

  Future<AudioResult> _describeAudio(
    String artifact,
    String path,
    int track, {
    required bool reused,
  }) async {
    final probe = await media.processor.probe(path);
    final s = probe.primaryAudio;
    if (s == null || s.sampleRate != 16000 || s.channels != 1) {
      throw const SubtitleException('audio_format_invalid');
    }
    return AudioResult(
      artifactId: artifact,
      trackIndex: track,
      sampleRate: s.sampleRate,
      channels: s.channels,
      durationMs: probe.duration?.inMilliseconds ?? 0,
      bytes: await File(path).length(),
      reused: reused,
    );
  }

  /// Internal audio path for the debug page's audition only.
  String? audioPath(String artifactId) => media.artifactPath(artifactId);

  SubtitleRun? run(String taskId) => _runs[taskId];

  // --------------------------------------------------------- tasks (AI)

  Map<String, dynamic>? task(String id) {
    final rows = db.select('SELECT * FROM transcription_tasks WHERE id=?', [
      id,
    ]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    final run = _runs[id];
    final binding = db.select(
      'SELECT id,subtitle_artifact_id,transcript_artifact_id FROM subtitle_bindings WHERE task_id=? ORDER BY created DESC LIMIT 1',
      [id],
    );
    return {
      'task_id': id,
      'status': run?.current.status.name ?? r['state'],
      'stage': run?.current.stage.name ?? r['stage'],
      'resource_name': r['resource_name'],
      'range_start_ms': r['range_start_ms'],
      'range_end_ms': ?r['range_end_ms'] as int?,
      'whole_media': r['whole'] == 1,
      'backend': ?r['backend_kind'] as String?,
      'model_id': ?r['model_id'] as String?,
      'language': ?r['language'] as String?,
      'error_code': ?r['error'] as String?,
      'audio_artifact_ref': ?r['audio_artifact_id'] as String?,
      'transcript_available': r['transcript_path'] != null,
      'transcript_artifact_ref': ?r['transcript_artifact_id'] as String?,
      'subtitle_artifact_ref': ?r['subtitle_artifact_id'] as String?,
      'segment_count': ?run?.current.transcript?.segments.length,
      if (binding.isNotEmpty) ...{
        'saved': true,
        'binding_id': binding.first['id'],
      },
    };
  }

  Map<String, dynamic> cancel(String id) {
    _runs[id]?.cancel();
    return task(id) ?? (throw const SubtitleException('not_found'));
  }

  Transcript? transcript(String taskId) {
    final rows = db.select(
      'SELECT transcript_path FROM transcription_tasks WHERE id=?',
      [taskId],
    );
    final p = rows.isEmpty ? null : rows.first['transcript_path'] as String?;
    if (p == null || !File(p).existsSync()) return null;
    return Transcript.fromJson(
      jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>,
    );
  }

  /// Subtitle text of a finished task (preview/export); never written to an
  /// external location here.
  String subtitleText(String taskId, SubtitleFormat format) {
    final t = transcript(taskId);
    if (t == null) throw const SubtitleException('transcript_unavailable');
    return serialize(buildCues(t.segments), format, note: _note(t));
  }

  static String _note(Transcript t) =>
      'OpenPlayX ${t.backend}/${t.modelId} ${t.wholeMedia ? 'full' : 'partial ${t.rangeStartMs}-${t.rangeEndMs} ms'}';

  // ---------------------------------------------------------------- save

  /// Explicit "save subtitle": registers the transcript and subtitle as
  /// persistent artifacts and creates a new binding to this resource
  /// version. Never overwrites an existing subtitle or touches playback.
  Future<Map<String, dynamic>> save(
    String taskId, {
    SubtitleFormat format = SubtitleFormat.srt,
  }) async {
    final rows = db.select('SELECT * FROM transcription_tasks WHERE id=?', [
      taskId,
    ]);
    if (rows.isEmpty) throw const SubtitleException('not_found');
    final r = rows.first;
    final t = transcript(taskId);
    if (r['state'] != 'succeeded' || t == null) {
      throw const SubtitleException('transcript_unavailable');
    }
    if (t.segments.isEmpty) throw const SubtitleException('transcript_empty');
    final text = serialize(buildCues(t.segments), format, note: _note(t));
    final dir = await _dir('saved');
    final bindingId = _id('binding');
    final subtitleArtifact = _id('artifact');
    final transcriptArtifact = _id('artifact');
    final subtitlePath = '${dir.path}/$bindingId.${format.extension}';
    final transcriptPath = '${dir.path}/$bindingId.transcript.json';
    // Files first (.part → rename), then one transaction for the rows; a
    // crash in between leaves unregistered files that recover() removes.
    Future<int> write(String path, String content) async {
      final part = File('$path.part');
      await part.writeAsString(content, flush: true);
      await part.rename(path);
      return File(path).length();
    }

    final subtitleBytes = await write(subtitlePath, text);
    final transcriptBytes = await write(transcriptPath, jsonEncode(t.toJson()));
    final base = (r['resource_name'] as String)
        .replaceAll('\\', '/')
        .split('/')
        .last;
    final partial = !t.wholeMedia;
    final label = partial
        ? '${t.rangeStartMs ~/ 1000}-${t.rangeEndMs ~/ 1000}s'
        : 'full';
    db.execute('BEGIN');
    try {
      db.execute('INSERT INTO media_artifacts VALUES (?,?,?,?,?,?,?)', [
        subtitleArtifact,
        taskId,
        'subtitle',
        subtitlePath,
        '$base.${t.language}.asr.$label.${format.extension}',
        subtitleBytes,
        _now,
      ]);
      db.execute('INSERT INTO media_artifacts VALUES (?,?,?,?,?,?,?)', [
        transcriptArtifact,
        taskId,
        'transcript',
        transcriptPath,
        '$base.${t.language}.asr.$label.json',
        transcriptBytes,
        _now,
      ]);
      db.execute(
        '''INSERT INTO subtitle_bindings (id,task_id,subtitle_artifact_id,
           transcript_artifact_id,resource_source,resource_item,fingerprint,
           track_index,range_start_ms,range_end_ms,partial,language,backend,
           model_id,model_revision,preset_revision,format,created)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
        [
          bindingId,
          taskId,
          subtitleArtifact,
          transcriptArtifact,
          r['resource_source'],
          r['resource_item'],
          r['fingerprint'],
          r['track_index'],
          t.rangeStartMs,
          t.rangeEndMs,
          partial ? 1 : 0,
          t.language,
          t.backend,
          t.modelId,
          t.modelRevision,
          MediaPreset.speechWav.revision,
          format.extension,
          _now,
        ],
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
    if (!_changes.isClosed) _changes.add(taskId);
    return {
      'binding_id': bindingId,
      'subtitle_artifact_ref': subtitleArtifact,
      'transcript_artifact_ref': transcriptArtifact,
      'partial': partial,
      'format': format.extension,
    };
  }

  /// Saved subtitles bound to a resource (newest first).
  List<Map<String, dynamic>> bindings(ResourceRef ref) => [
    for (final b in db.select(
      'SELECT * FROM subtitle_bindings WHERE resource_source=? AND resource_item=? ORDER BY created DESC',
      [ref.instanceId, ref.id],
    ))
      {
        'binding_id': b['id'],
        'subtitle_artifact_ref': b['subtitle_artifact_id'],
        'language': b['language'],
        'partial': b['partial'] == 1,
        'range_start_ms': b['range_start_ms'],
        'range_end_ms': b['range_end_ms'],
        'format': b['format'],
      },
  ];

  // ------------------------------------------------------------ cleanup

  /// Removes what an unsaved run produced: its transcript file and, when it
  /// created (not reused) the audio, that audio artifact. Saved outputs are
  /// separate artifacts and are not affected.
  Future<void> discard(String taskId) async {
    final rows = db.select('SELECT * FROM transcription_tasks WHERE id=?', [
      taskId,
    ]);
    if (rows.isEmpty) return;
    final r = rows.first;
    final path = r['transcript_path'] as String?;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    final audio = r['audio_artifact_id'] as String?;
    if (audio != null && r['audio_owned'] == 1) {
      final users = db.select(
        'SELECT 1 FROM transcription_tasks WHERE audio_artifact_id=? AND id<>? AND audio_owned=0',
        [audio, taskId],
      );
      if (users.isEmpty) await media.deleteArtifact(audio);
    }
    _update(taskId, {'transcript_path': null, 'audio_artifact_id': null});
  }

  /// Startup: unfinished tasks become interrupted (no background promise),
  /// debug leftovers are removed, unregistered saved files are deleted and
  /// pending remote deletions are retried.
  Future<void> recover() async {
    db.execute(
      "UPDATE transcription_tasks SET state='interrupted',error='interrupted',updated=? WHERE state IN ('running','cancelling')",
      [_now],
    );
    for (final row in db.select(
      "SELECT id FROM transcription_tasks WHERE caller='debug' AND (transcript_path IS NOT NULL OR audio_artifact_id IS NOT NULL)",
    )) {
      await discard(row['id'] as String);
    }
    if (await root == null) return;
    final saved = await _dir('saved');
    await for (final f in saved.list()) {
      if (f is! File) continue;
      if (f.path.endsWith('.part') ||
          db.select('SELECT 1 FROM media_artifacts WHERE path=?', [
            f.path,
          ]).isEmpty) {
        await f.delete();
      }
    }
    for (final row in db.select(
      "SELECT id,backend_id,remote_job_id FROM transcription_tasks WHERE remote_cleanup='pending' OR (remote_job_id IS NOT NULL AND remote_cleanup IS NULL)",
    )) {
      final backend = row['backend_id'] as String?;
      if (backend != null) {
        unawaited(
          _cleanupRemote(
            row['id'] as String,
            backend,
            row['remote_job_id'] as String,
          ),
        );
      }
    }
  }

  void dispose() {
    for (final run in [..._runs.values]) {
      run.cancel();
    }
    unawaited(_changes.close());
  }
}

/// The debug page's scope (design §3.3): one selected resource; leaving
/// cancels unfinished work and discards unsaved outputs.
class DebugSubtitleSession {
  DebugSubtitleSession(this.service, this.resource);
  final SubtitleGenerationService service;
  final ResourceRef resource;
  final _tasks = <String>[];
  bool _closed = false;

  SubtitleRun start(SubtitleRequest r) {
    if (_closed) throw const SubtitleException('closed');
    if (r.resource.instanceId != resource.instanceId ||
        r.resource.id != resource.id) {
      throw const SubtitleException('access_denied');
    }
    final run = service.start(r);
    if (!_tasks.contains(run.taskId)) _tasks.add(run.taskId);
    return run;
  }

  Future<Map<String, dynamic>> save(
    String taskId,
    SubtitleFormat format,
  ) async {
    return service.save(taskId, format: format);
  }

  /// Cancels running work and waits for it to really stop before discarding
  /// its files (native work is never released early).
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final id in _tasks) {
      final run = service.run(id);
      if (run != null) {
        run.cancel();
        try {
          await run.done;
        } catch (_) {}
      }
    }
    for (final id in _tasks) {
      await service.discard(id);
    }
  }
}
