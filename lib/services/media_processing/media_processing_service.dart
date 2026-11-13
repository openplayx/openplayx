import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:openplayx_ffmpeg/openplayx_ffmpeg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_manager.dart';

export 'package:openplayx_ffmpeg/openplayx_ffmpeg.dart'
    show
        MediaErrorCode,
        MediaException,
        MediaJobState,
        MediaPreset,
        MediaPlanner,
        MediaOperation,
        MediaProbe,
        MediaStreamInfo,
        MediaCapabilities,
        PlanRequest;

/// Host coordination around the in-process FFmpeg package: resolves
/// authorised resources to inputs, persists tasks, publishes artifacts and
/// recovers after restarts. All media work happens in `openplayx_ffmpeg`.
///
/// Paths, stream URLs and raw errors never leave this class; callers get
/// task/artifact ids and short codes.
class MediaProcessingService {
  MediaProcessingService({
    required this.db,
    required this.sources,
    required this.root,
    MediaProcessor? processor,
    this.quotaBytes = 5 * 1024 * 1024 * 1024,
  }) : processor = processor ?? sharedProcessor {
    db.execute('''CREATE TABLE IF NOT EXISTS processing_tasks (
      id TEXT PRIMARY KEY, operation TEXT NOT NULL, preset_id TEXT NOT NULL,
      preset_revision INTEGER NOT NULL, resource_source TEXT NOT NULL,
      resource_item TEXT NOT NULL, resource_name TEXT NOT NULL,
      params TEXT NOT NULL, state TEXT NOT NULL, error TEXT, reason TEXT,
      processed_ms INTEGER NOT NULL DEFAULT 0, total_ms INTEGER,
      output TEXT, artifact_id TEXT, attempt_of TEXT,
      created INTEGER NOT NULL, updated INTEGER NOT NULL)''');
    db.execute('''CREATE TABLE IF NOT EXISTS media_artifacts (
      id TEXT PRIMARY KEY, task_id TEXT NOT NULL, kind TEXT NOT NULL,
      path TEXT NOT NULL, name TEXT NOT NULL, bytes INTEGER NOT NULL,
      created INTEGER NOT NULL)''');
  }

  /// The app's instance, set by the shell once the library is open. Used by
  /// the detail page's snapshot debug entry; null when unavailable.
  static MediaProcessingService? current;

  /// `<application support>/media_processing`, or null where the platform
  /// directory is unavailable (e.g. widget tests).
  static Future<Directory?> defaultRoot() async {
    try {
      final base = await getApplicationSupportDirectory();
      return Directory('${base.path}/media_processing');
    } catch (_) {
      return null;
    }
  }

  /// One processor per process: its queue enforces business concurrency 1.
  static final sharedProcessor = MediaProcessor();

  final Database db;
  final SourceManager sources;

  /// App-private directory (resolved lazily so startup never waits on it);
  /// artifacts live in `<root>/artifacts`, debug snapshots in `<root>/debug`.
  final Future<Directory?> root;
  final MediaProcessor processor;
  final int quotaBytes;
  final _jobs = <String, MediaJob>{};
  final _cancelled = <String>{};
  final _changes = StreamController<String>.broadcast();

  /// Emits task ids whenever a task's state or progress changes.
  Stream<String> get changes => _changes.stream;
  bool get available => processor.available;
  Future<Directory> _dir(String name) async {
    final base = await root;
    if (base == null) throw const MediaException(MediaErrorCode.unavailable);
    return Directory('${base.path}/$name');
  }

  Future<Directory> get _artifacts => _dir('artifacts');
  Future<Directory> get _debug => _dir('debug');

  static String _id(String prefix) {
    final r = Random.secure();
    return '$prefix-${List.generate(12, (_) => r.nextInt(16).toRadixString(16)).join()}';
  }

  static int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<MediaCapabilities> capabilities() => processor.capabilities();

  // ------------------------------------------------------------- inputs

  /// Resolves to an absolute local path or the host's loopback session
  /// stream. Remote URLs (which FFmpeg would fetch itself) are refused.
  Future<_Input> _open(ResourceRef ref) async {
    if (ref.instanceId == '@local') {
      final file = File(ref.id);
      if (!file.isAbsolute || !await file.exists()) {
        throw const MediaException(MediaErrorCode.inputUnavailable);
      }
      return _Input(file.path, null);
    }
    final PlayableStream stream;
    try {
      stream = await sources.resolve(ref);
    } catch (_) {
      throw const MediaException(MediaErrorCode.inputUnavailable);
    }
    final uri = stream.uri;
    if (uri.scheme == 'file') return _Input(uri.toFilePath(), stream);
    if (uri.scheme == 'http' &&
        (uri.host == '127.0.0.1' || uri.host == 'localhost')) {
      return _Input(uri.toString(), stream);
    }
    await stream.release();
    throw const MediaException(
      MediaErrorCode.accessDenied,
      'remote_stream_requires_download',
    );
  }

  Future<MediaProbe> probe(ResourceRef ref) async {
    final input = await _open(ref);
    try {
      return await processor.probe(input.location);
    } finally {
      await input.release();
    }
  }

  // -------------------------------------------------------------- tasks

  Map<String, dynamic>? task(String id) {
    final rows = db.select('SELECT * FROM processing_tasks WHERE id=?', [id]);
    return rows.isEmpty ? null : _taskJson(rows.first);
  }

  List<Map<String, dynamic>> tasks({int offset = 0, int limit = 20}) => [
    for (final row in db.select(
      'SELECT * FROM processing_tasks ORDER BY created DESC LIMIT ? OFFSET ?',
      [limit, offset],
    ))
      _taskJson(row),
  ];

  /// Internal artifact location for host-side preview/export flows only.
  String? artifactPath(String artifactId) {
    final rows = db.select('SELECT path FROM media_artifacts WHERE id=?', [
      artifactId,
    ]);
    return rows.isEmpty ? null : rows.first['path'] as String;
  }

  /// Removes an artifact's registration and file (debug cache cleanup).
  Future<void> deleteArtifact(String artifactId) async {
    final path = artifactPath(artifactId);
    if (path == null) return;
    db.execute('DELETE FROM media_artifacts WHERE id=?', [artifactId]);
    db.execute(
      'UPDATE processing_tasks SET artifact_id=NULL WHERE artifact_id=?',
      [artifactId],
    );
    try {
      await File(path).delete();
    } catch (_) {}
  }

  Map<String, dynamic> _taskJson(Row r) {
    final total = r['total_ms'] as int?;
    final artifact = r['artifact_id'] as String?;
    Map<String, dynamic>? artifactJson;
    if (artifact != null) {
      final a = db.select('SELECT * FROM media_artifacts WHERE id=?', [
        artifact,
      ]);
      if (a.isNotEmpty) {
        artifactJson = {
          'artifact_ref': artifact,
          'kind': a.first['kind'],
          'name': a.first['name'],
          'bytes': a.first['bytes'],
        };
      }
    }
    final error = r['error'] as String?;
    return {
      'task_id': r['id'],
      'operation': r['operation'],
      'preset_id': r['preset_id'],
      'preset_revision': r['preset_revision'],
      'resource_name': r['resource_name'],
      'status': r['state'],
      'processed_ms': r['processed_ms'],
      'total_ms': ?total,
      if (total != null && total > 0)
        'progress': ((r['processed_ms'] as int) / total).clamp(0, 1),
      if (error != null) ...{
        'error_code': error,
        'retryable': MediaErrorCode.values
            .where((e) => e.name == error)
            .any((e) => e.retryable),
      },
      'reason': ?r['reason'] as String?,
      'artifact': ?artifactJson,
      'attempt_of': ?r['attempt_of'] as String?,
    };
  }

  void _update(String id, Map<String, Object?> values) {
    final keys = values.keys.toList();
    db.execute(
      'UPDATE processing_tasks SET ${keys.map((k) => '$k=?').join(',')},updated=? WHERE id=?',
      [...keys.map((k) => values[k]), _now, id],
    );
    if (!_changes.isClosed) _changes.add(id);
  }

  int _usedBytes() =>
      db
              .select('SELECT COALESCE(SUM(bytes),0) AS n FROM media_artifacts')
              .first['n']
          as int;

  /// Validates the preset and persists a queued task, then returns at once;
  /// probing, planning and encoding continue in the background.
  Map<String, dynamic> submit({
    required ResourceRef ref,
    required String resourceName,
    required String presetId,
    required int presetRevision,
    required MediaOperation operation,
    PlanRequest request = const PlanRequest(),
    String? attemptOf,
  }) {
    final preset = MediaPreset.byId(presetId);
    if (preset == null || preset.operation != operation) {
      throw const MediaException(MediaErrorCode.invalidArgument, 'preset');
    }
    if (preset.revision != presetRevision) {
      throw const MediaException(
        MediaErrorCode.presetIncompatible,
        'preset_revision_changed',
      );
    }
    if (!available) throw const MediaException(MediaErrorCode.unavailable);
    if (_usedBytes() >= quotaBytes) {
      throw const MediaException(MediaErrorCode.noSpace, 'artifact_quota');
    }
    final params = jsonEncode({
      'start_us': ?request.start?.inMicroseconds,
      'end_us': ?request.end?.inMicroseconds,
      'time_us': ?request.time?.inMicroseconds,
      'audio_stream': ?request.audioStream,
      'subtitle_stream': ?request.subtitleStream,
    });
    // The same request while one is active maps to the same task.
    final active = db.select(
      '''SELECT id FROM processing_tasks WHERE preset_id=? AND resource_source=?
         AND resource_item=? AND params=? AND state IN
         ('queued','preparing','running','finalizing','cancelling')''',
      [presetId, ref.instanceId, ref.id, params],
    );
    if (active.isNotEmpty) return task(active.first['id'] as String)!;
    final id = _id('task');
    db.execute(
      '''INSERT INTO processing_tasks (id,operation,preset_id,preset_revision,
         resource_source,resource_item,resource_name,params,state,attempt_of,
         created,updated) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)''',
      [
        id,
        operation.name,
        presetId,
        presetRevision,
        ref.instanceId,
        ref.id,
        resourceName,
        params,
        'queued',
        attemptOf,
        _now,
        _now,
      ],
    );
    unawaited(_execute(id, preset, ref, request));
    return task(id)!;
  }

  Future<void> _execute(
    String id,
    MediaPreset preset,
    ResourceRef ref,
    PlanRequest request,
  ) async {
    _Input? input;
    try {
      _update(id, {'state': 'preparing'});
      input = await _open(ref);
      if (_cancelled.contains(id)) {
        throw const MediaException(MediaErrorCode.cancelled);
      }
      final caps = await processor.capabilities();
      final probe = await processor.probe(input.location);
      if (_cancelled.contains(id)) {
        throw const MediaException(MediaErrorCode.cancelled);
      }
      final plan = MediaPlanner.plan(preset, probe, caps, request);
      final dir = await (await _artifacts).create(recursive: true);
      final output = '${dir.path}/$id.${plan.extension}';
      _update(id, {'output': output});
      final job = _jobs[id] = processor.submit(
        plan,
        input: input.location,
        output: output,
      );
      if (_cancelled.contains(id)) job.cancel();
      var lastWrite = 0;
      final sub = job.progress.listen((p) {
        final now = _now;
        if (!p.state.terminal &&
            now - lastWrite < 1000 &&
            p.state != MediaJobState.cancelling) {
          return; // rate-limited progress persistence
        }
        lastWrite = now;
        _update(id, {
          if (!p.state.terminal) 'state': p.state.name,
          'processed_ms': p.processed.inMilliseconds,
          'total_ms': p.total?.inMilliseconds,
        });
      });
      final result = await job.done;
      await sub.cancel();
      if (!result.succeeded) {
        _update(id, {
          'state': result.state.name,
          'error': (result.error ?? MediaErrorCode.nativeFailure).name,
        });
        return;
      }
      _publish(id, preset, result.outputPath!, result.bytes ?? 0);
    } on MediaException catch (e) {
      final cancelled = e.code == MediaErrorCode.cancelled;
      _update(id, {
        'state': cancelled ? 'cancelled' : 'failed',
        'error': e.code.name,
        'reason': e.reason,
      });
    } catch (_) {
      _update(id, {
        'state': 'failed',
        'error': MediaErrorCode.nativeFailure.name,
      });
    } finally {
      _jobs.remove(id);
      _cancelled.remove(id);
      await input?.release();
    }
  }

  void _publish(String taskId, MediaPreset preset, String path, int bytes) {
    final artifact = _id('artifact');
    final ext = path.split('.').last;
    final kind = switch (preset.operation) {
      MediaOperation.snapshot => 'image',
      MediaOperation.extractAudio => 'audio',
      MediaOperation.transcode => 'video',
    };
    final row = db.select(
      'SELECT resource_name FROM processing_tasks WHERE id=?',
      [taskId],
    );
    final base = row.isEmpty
        ? 'media'
        : _safeName(row.first['resource_name'] as String);
    db.execute('BEGIN');
    try {
      db.execute('INSERT INTO media_artifacts VALUES (?,?,?,?,?,?,?)', [
        artifact,
        taskId,
        kind,
        path,
        '$base.${preset.id}.$ext',
        bytes,
        _now,
      ]);
      db.execute(
        "UPDATE processing_tasks SET state='succeeded',artifact_id=?,processed_ms=COALESCE(total_ms,processed_ms),updated=? WHERE id=?",
        [artifact, _now, taskId],
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow; // recover() registers the file on next start
    }
    if (!_changes.isClosed) _changes.add(taskId);
  }

  static String _safeName(String name) {
    final base = name.replaceAll('\\', '/').split('/').last;
    final dot = base.lastIndexOf('.');
    final stem = (dot > 0 ? base.substring(0, dot) : base).replaceAll(
      RegExp(r'[^\w\-一-鿿 ]'),
      '_',
    );
    return stem.substring(0, min(60, stem.length));
  }

  Map<String, dynamic> cancel(String id) {
    final t = task(id);
    if (t == null) {
      throw const MediaException(MediaErrorCode.invalidArgument, 'task');
    }
    final state = t['status'] as String;
    if (const [
      'succeeded',
      'failed',
      'cancelled',
      'interrupted',
    ].contains(state)) {
      return t;
    }
    _cancelled.add(id);
    final job = _jobs[id];
    if (job != null) {
      job.cancel();
      // Stays `cancelling` until native work really stops.
      if (!job.current.state.terminal) _update(id, {'state': 'cancelling'});
    } else {
      _update(id, {'state': 'cancelling'});
    }
    return task(id)!;
  }

  /// A new attempt re-checks resource, preset, quota and device capability.
  Map<String, dynamic> retry(String id) {
    final rows = db.select('SELECT * FROM processing_tasks WHERE id=?', [id]);
    if (rows.isEmpty) {
      throw const MediaException(MediaErrorCode.invalidArgument, 'task');
    }
    final r = rows.first;
    if (!const ['failed', 'cancelled', 'interrupted'].contains(r['state'])) {
      throw const MediaException(
        MediaErrorCode.invalidArgument,
        'task_not_retryable',
      );
    }
    final p = jsonDecode(r['params'] as String) as Map<String, dynamic>;
    Duration? us(String k) =>
        p[k] == null ? null : Duration(microseconds: p[k] as int);
    return submit(
      ref: ResourceRef(
        r['resource_source'] as String,
        r['resource_item'] as String,
      ),
      resourceName: r['resource_name'] as String,
      presetId: r['preset_id'] as String,
      presetRevision: r['preset_revision'] as int,
      operation: MediaOperation.values.byName(r['operation'] as String),
      request: PlanRequest(
        start: us('start_us'),
        end: us('end_us'),
        time: us('time_us'),
        audioStream: p['audio_stream'] as int?,
        subtitleStream: p['subtitle_stream'] as int?,
      ),
      attemptOf: id,
    );
  }

  /// Startup reconciliation: unfinished tasks become `interrupted`, files
  /// published but not registered are registered (or removed), temporary
  /// and debug files are cleaned. No resumable transcoding is promised.
  Future<void> recover() async {
    db.execute(
      '''UPDATE processing_tasks SET state='interrupted',error='interrupted',updated=?
         WHERE state IN ('queued','preparing','running','finalizing','cancelling')''',
      [_now],
    );
    if (await root == null) return;
    final debug = await _debug;
    if (await debug.exists()) {
      await debug.delete(recursive: true);
    }
    for (final row in db.select('SELECT id,path FROM media_artifacts')) {
      if (!File(row['path'] as String).existsSync()) {
        db.execute('DELETE FROM media_artifacts WHERE id=?', [row['id']]);
        db.execute(
          'UPDATE processing_tasks SET artifact_id=NULL WHERE artifact_id=?',
          [row['id']],
        );
      }
    }
    final artifacts = await _artifacts;
    if (!await artifacts.exists()) return;
    await for (final entity in artifacts.list()) {
      if (entity is! File) continue;
      final path = entity.path;
      if (path.endsWith('.part')) {
        await entity.delete();
        continue;
      }
      if (db.select('SELECT 1 FROM media_artifacts WHERE path=?', [
        path,
      ]).isNotEmpty) {
        continue;
      }
      final rows = db.select('SELECT * FROM processing_tasks WHERE output=?', [
        path,
      ]);
      final preset = rows.isEmpty
          ? null
          : MediaPreset.byId(rows.first['preset_id'] as String);
      if (preset == null) {
        await entity.delete();
      } else {
        // Renamed into place but not registered before exit: compensate.
        _publish(
          rows.first['id'] as String,
          preset,
          path,
          await entity.length(),
        );
      }
    }
  }

  // ------------------------------------------------- debug snapshot (9.1)

  /// Random frame between 20% and 80% of the effective duration of one
  /// authorised resource. Results are temporary and never touch artwork.
  DebugSnapshot debugSnapshot(ResourceRef ref, {Random? random}) =>
      DebugSnapshot._(this, ref, random ?? Random());

  void dispose() {
    for (final job in _jobs.values) {
      job.cancel();
    }
    unawaited(_changes.close());
  }
}

class _Input {
  _Input(this.location, this.stream);
  final String location;
  final PlayableStream? stream;
  Future<void> release() async => stream?.release();
}

class DebugSnapshotResult {
  const DebugSnapshotResult(this.time, this.duration, this.file);
  final Duration time;
  final Duration duration;
  final File file;
}

class DebugSnapshot {
  DebugSnapshot._(this._service, this._ref, this._random) {
    result = _run();
  }
  final MediaProcessingService _service;
  final ResourceRef _ref;
  final Random _random;
  late final Future<DebugSnapshotResult> result;
  MediaJob? _job;
  bool _cancelled = false;
  File? _file;

  void cancel() {
    _cancelled = true;
    _job?.cancel();
  }

  /// Cancels and deletes the temporary image.
  Future<void> dispose() async {
    cancel();
    try {
      await result;
    } catch (_) {}
    try {
      await _file?.delete();
    } catch (_) {}
  }

  void _check() {
    if (_cancelled) throw const MediaException(MediaErrorCode.cancelled);
  }

  Future<DebugSnapshotResult> _run() async {
    final input = await _service._open(_ref);
    try {
      _check();
      final processor = _service.processor;
      final caps = await processor.capabilities();
      final probe = await processor.probe(input.location);
      _check();
      final duration = probe.duration;
      if (duration == null) {
        throw const MediaException(
          MediaErrorCode.inputUnsupported,
          'duration_unknown',
        );
      }
      final us = duration.inMicroseconds;
      final at = Duration(
        microseconds: (us * (0.2 + 0.6 * _random.nextDouble())).floor(),
      );
      final plan = MediaPlanner.plan(
        MediaPreset.imagePreview,
        probe,
        caps,
        PlanRequest(time: at),
      );
      final debug = await (await _service._debug).create(recursive: true);
      final output =
          '${debug.path}/${MediaProcessingService._id('snap')}.${plan.extension}';
      final job = _job = processor.submit(
        plan,
        input: input.location,
        output: output,
      );
      if (_cancelled) job.cancel();
      final r = await job.done;
      if (!r.succeeded) {
        throw MediaException(r.error ?? MediaErrorCode.nativeFailure);
      }
      _file = File(r.outputPath!);
      if (_cancelled) {
        await _file!.delete();
        throw const MediaException(MediaErrorCode.cancelled);
      }
      return DebugSnapshotResult(at, duration, _file!);
    } finally {
      await input.release();
    }
  }
}
