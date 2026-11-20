import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../capabilities/sources/source_manager.dart';
import '../../../core/capabilities/source_capability.dart';
import '../../../data/sources/file_sources.dart';
import '../../../data/sources/source_schema.dart';
import '../plugin_access.dart';
import '../tools/tool_registry.dart';
import '../tools/task_wait.dart';
import 'external_service_registry.dart';

/// File transport is deliberately independent of MCP resources and tool output.
/// Only host-constructed paths on an explicitly configured service are fetched.
class ExternalFileDownload {
  ExternalFileDownload(this.uri, this.token, {this.check});
  final Uri uri;
  final String token;
  final void Function()? check;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30);
  bool _cancelled = false;
  Completer<void>? _delay;

  static Uri fileUri(ExternalService service, String job, int index) {
    final base = Uri.parse(service.baseUrl);
    final endpoint = Uri.parse(service.endpoint);
    if (!{'http', 'https'}.contains(base.scheme) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        base.origin != endpoint.origin ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(job) ||
        index < 0) {
      throw const ToolFailure('external_address_rejected');
    }
    final prefix = base.path.replaceFirst(RegExp(r'/+$'), '');
    return base.replace(path: '$prefix/files/$job/$index');
  }

  void cancel() {
    _cancelled = true;
    _client.close(force: true);
    if (!(_delay?.isCompleted ?? true)) _delay!.complete();
  }

  void _check() {
    if (_cancelled) throw const ToolFailure('cancelled');
    check?.call();
  }

  Future<HttpClientResponse> _open(
    String method, {
    int offset = 0,
    String? etag,
  }) async {
    _check();
    final request = await _client.openUrl(method, uri);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    if (offset > 0) {
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
      request.headers.set(HttpHeaders.ifRangeHeader, etag!);
    }
    final response = await request.close().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        request.abort();
        throw TimeoutException('file headers');
      },
    );
    if (response.isRedirect ||
        (response.statusCode >= 300 && response.statusCode < 400)) {
      request.abort();
      throw const ToolFailure('external_redirect_rejected');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      request.abort();
      throw const ToolFailure('external_read_permission_required');
    }
    if (response.statusCode != 200 && response.statusCode != 206) {
      request.abort();
      throw ToolFailure('external_file_http_${response.statusCode}');
    }
    return response;
  }

  Future<({String name, int length, String etag})> metadata() async {
    final response = await _open('HEAD');
    final length = response.contentLength;
    final etag = response.headers.value('etag');
    final disposition = response.headers.value('content-disposition') ?? '';
    final encoded = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition)?.group(1);
    await response.drain<void>();
    if (response.headers.value('content-encoding') != null ||
        length < 0 ||
        etag == null ||
        etag.startsWith('W/') ||
        encoded == null) {
      throw const ToolFailure('external_file_metadata_invalid');
    }
    final name = Uri.decodeComponent(encoded);
    validateWriteName(name);
    return (name: name, length: length, etag: etag);
  }

  /// Resumes the HTTP leg without replaying bytes already delivered to the
  /// destination sink. If-Range and exact Content-Range prevent mixed files.
  Stream<List<int>> read(int length, String etag, {int offset = 0}) async* {
    var received = offset;
    var failures = 0;
    while (received < length) {
      _check();
      try {
        final response = await _open('GET', offset: received, etag: etag);
        final expectedRange = 'bytes $received-${length - 1}/$length';
        if (response.headers.value('content-encoding') != null ||
            response.headers.value('etag') != etag ||
            response.contentLength != length - received ||
            (received > 0 &&
                (response.statusCode != 206 ||
                    response.headers.value('content-range') !=
                        expectedRange)) ||
            (received == 0 && response.statusCode != 200)) {
          cancel();
          throw const ToolFailure('external_file_changed_or_range_unsupported');
        }
        await for (final chunk in response.timeout(
          const Duration(seconds: 30),
        )) {
          _check();
          if (received + chunk.length > length) {
            throw const ToolFailure('external_file_length_mismatch');
          }
          received += chunk.length;
          failures = 0;
          yield chunk;
        }
        if (received < length) {
          throw const SocketException('Incomplete download');
        }
      } on ToolFailure {
        rethrow;
      } on PluginException {
        rethrow;
      } catch (_) {
        _check();
        if (++failures > 30) {
          throw const ToolFailure('external_network_unavailable');
        }
        _delay = Completer<void>();
        await _delay!.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () {},
        );
      }
    }
  }
}

/// Durable background jobs. No credentials or remote URLs are persisted.
/// On process restart cached jobs can resume through task_retry; interrupted
/// stream writes are retried as a fresh exclusive destination write.
class ExternalFileTransfers {
  ExternalFileTransfers({
    required this.db,
    required this.services,
    required this.sources,
    this.access,
    this.issueReference,
    Future<Directory> Function()? cacheDirectory,
    Future<int?> Function()? availableBytes,
  }) : _cacheDirectory = cacheDirectory ?? getTemporaryDirectory,
       _availableBytes = availableBytes ?? _diskBytes {
    db.execute(
      'CREATE TABLE IF NOT EXISTS external_file_tasks '
      '(id TEXT PRIMARY KEY, data TEXT NOT NULL)',
    );
    for (final row in db.select('SELECT id,data FROM external_file_tasks')) {
      final task = Map<String, dynamic>.from(
        jsonDecode(row['data'] as String) as Map,
      );
      if (!{
        'succeeded',
        'failed',
        'cancelled',
        'interrupted',
      }.contains(task['status'])) {
        task['status'] = 'interrupted';
      }
      _tasks[row['id'] as String] = task;
    }
  }
  final Database db;
  final ExternalServiceRegistry services;
  final SourceManager sources;
  final PluginAccess? access;
  final Map<String, dynamic> Function(SourceEntry)? issueReference;
  final Future<Directory> Function() _cacheDirectory;
  final Future<int?> Function() _availableBytes;
  final _tasks = <String, Map<String, dynamic>>{};
  final _downloads = <String, ExternalFileDownload>{};
  final _cancelled = <String>{};
  final _writes = <String, SourceWriteCancellation>{};
  final _changes = StreamController<String>.broadcast();
  Future<void> _queue = Future.value();
  bool _disposed = false;
  Stream<String> get changes => _changes.stream;

  static Future<int?> _diskBytes() async {
    try {
      return await const MethodChannel('openplayx/transfer_storage')
          .invokeMethod<int>('availableBytes');
    } catch (_) {
      return null;
    }
  }

  void _allowed(String target) {
    final config = sources.configs
        .where((c) => c.id == target && c.enabled)
        .firstOrNull;
    if (config == null) throw const ToolFailure('target_source_unavailable');
    if (!SourceSchemas.forKind(config.kind).capabilities
        .contains('source.write')) {
      throw const ToolFailure('sourceNotWritable');
    }
    if (!(access?.aiAllows(
          config.providerId,
          instanceId: target,
          capability: 'source.write',
        ) ??
        true)) {
      throw const ToolFailure('permissionDenied:source.write');
    }
  }

  Map<String, dynamic>? task(String id) {
    final t = _tasks[id];
    if (t == null) return null;
    return {
      for (final e in t.entries)
        if (!e.key.startsWith('_')) e.key: e.value,
    };
  }

  List<Map<String, dynamic>> tasks() =>
      _tasks.keys.toList().reversed.map((id) => task(id)!).toList();

  void _emit(String id) {
    if (_disposed) return;
    db.execute(
      'INSERT OR REPLACE INTO external_file_tasks(id,data) VALUES (?,?)',
      [id, jsonEncode(_tasks[id])],
    );
    _changes.add(id);
  }

  Future<Map<String, dynamic>> submit(Map<String, dynamic> args) async {
    await sources.load();
    if (!services.loaded) await services.load();
    _allowed(args['target_instance_id'] as String);
    final service = services.get(args['service_id'] as String);
    if (service == null) throw const ToolFailure('external_service_removed');
    ExternalFileDownload.fileUri(
      service,
      args['job_id'] as String,
      args['file_index'] as int,
    );
    writeFolder('/', args['folder'] as String?);
    final key = jsonEncode([
      args['service_id'],
      args['job_id'],
      args['file_index'],
      args['target_instance_id'],
      args['folder'],
      args['transfer_mode'] ?? 'stream',
    ]);
    for (final t in _tasks.values) {
      if (t['_key'] == key &&
          !{'failed', 'cancelled', 'interrupted'}.contains(t['status'])) {
        return task(t['task_id'] as String)!;
      }
    }
    final id =
        'transfer-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    _tasks[id] = {
      ...args,
      'task_id': id,
      'status': 'queued',
      'stage': 'queued',
      'progress': 0,
      'transferred_bytes': 0,
      '_key': key,
      '_base_url': service.baseUrl,
      '_endpoint': service.endpoint,
    };
    _emit(id);
    _schedule(id);
    return task(id)!;
  }

  void _schedule(String id) {
    _queue = _queue.then((_) => _run(id)).catchError((Object _) {});
  }

  Map<String, dynamic> cancel(String id) {
    final t = _tasks[id];
    if (t == null) throw const ToolFailure('notFound');
    if (!{
      'succeeded',
      'failed',
      'cancelled',
      'interrupted',
    }.contains(t['status'])) {
      _cancelled.add(id);
      t['status'] = 'cancelling';
      _downloads[id]?.cancel();
      _writes[id]?.cancel();
      _emit(id);
    }
    return task(id)!;
  }

  Future<Map<String, dynamic>> retry(String id) async {
    await sources.load();
    if (!services.loaded) await services.load();
    final t = _tasks[id];
    if (t == null) throw const ToolFailure('notFound');
    _allowed(t['target_instance_id'] as String);
    if (!{'failed', 'interrupted', 'cancelled'}.contains(t['status'])) {
      throw const ToolFailure('taskNotRetryable');
    }
    _cancelled.remove(id);
    t['status'] = 'queued';
    t.remove('error');
    _emit(id);
    _schedule(id);
    return task(id)!;
  }

  Future<void> _run(String id) async {
    final t = _tasks[id]!;
    File? cache;
    var succeeded = false;
    final cancellation = _writes[id] = SourceWriteCancellation();
    void check() {
      if (_disposed || _cancelled.contains(id)) {
        throw const ToolFailure('cancelled');
      }
      _allowed(t['target_instance_id'] as String);
      final s = services.get(t['service_id'] as String);
      if (s == null ||
          s.baseUrl != t['_base_url'] ||
          s.endpoint != t['_endpoint']) {
        throw const ToolFailure('external_service_changed');
      }
    }

    try {
      check();
      t['status'] = 'running';
      t['stage'] = 'connecting';
      _emit(id);
      final service = services.get(t['service_id'] as String)!;
      final token = await services.token(service.id);
      if (token == null || token.isEmpty) {
        throw const ToolFailure('external_token_missing');
      }
      final download = _downloads[id] = ExternalFileDownload(
        ExternalFileDownload.fileUri(
          service,
          t['job_id'] as String,
          t['file_index'] as int,
        ),
        token,
        check: check,
      );
      final meta = await download.metadata().catchError((Object e) {
        if (e is ToolFailure || e is PluginException) throw e;
        throw const ToolFailure('external_service_unreachable');
      });
      t['resource_name'] = meta.name;
      t['total_bytes'] = meta.length;
      final cached = t['transfer_mode'] == 'cache';
      var received = 0;
      var lastEmit = DateTime.now();
      Stream<List<int>> progress(Stream<List<int>> input, String stage) async* {
        t['stage'] = stage;
        _emit(id);
        await for (final chunk in input) {
          check();
          received += chunk.length;
          t['transferred_bytes'] = received;
          t['progress'] = meta.length == 0 ? 1 : received / meta.length;
          if (DateTime.now().difference(lastEmit).inMilliseconds >= 500) {
            lastEmit = DateTime.now();
            _emit(id);
          }
          yield chunk;
        }
      }

      if (cached) {
        final dir = Directory(
          '${(await _cacheDirectory()).path}/external_file_transfers',
        );
        await dir.create(recursive: true);
        await _cleanCache(dir, id);
        cache = File('${dir.path}/$id.part');
        if (t['_etag'] != meta.etag && await cache.exists()) {
          await cache.delete();
        }
        received = await cache.exists() ? await cache.length() : 0;
        if (received > meta.length) {
          await cache.delete();
          received = 0;
        }
        final free = await _availableBytes();
        if (free == null) {
          throw const ToolFailure('cache_space_unavailable:use_stream');
        }
        if (free < meta.length - received + 64 * 1024 * 1024) {
          throw const ToolFailure('insufficient_cache_space:use_stream');
        }
        t['_etag'] = meta.etag;
        _emit(id);
        final sink = cache.openWrite(mode: FileMode.append);
        try {
          await sink.addStream(
            progress(
              download.read(meta.length, meta.etag, offset: received),
              'downloading',
            ),
          );
        } finally {
          await sink.close();
        }
        check();
        t['stage'] = 'writing';
        _emit(id);
      }
      final entry = await sources
          .writeNewStream(
            t['target_instance_id'] as String,
            meta.name,
            cached
                ? cache!.openRead()
                : progress(download.read(meta.length, meta.etag), 'writing'),
            meta.length,
            folder: t['folder'] as String?,
            cachedFile: cache,
            cancellation: cancellation,
          )
          .catchError((Object e) {
            if (e is ToolFailure) throw e;
            if (e is PluginException) {
              throw ToolFailure('target_source_${e.code}');
            }
            throw const ToolFailure(
              'target_source_unreachable_or_write_failed',
            );
          });
      // A completed exclusive write wins a cancellation racing publication.
      t.addAll({
        'status': 'succeeded',
        'stage': 'complete',
        'progress': 1,
        'transferred_bytes': meta.length,
        'saved': true,
        'name': entry.name,
        'folder': t['folder'] ?? 'OpenPlayX/Downloads',
        ...?issueReference?.call(entry),
      });
      succeeded = true;
    } catch (e) {
      Object failure = e;
      if (!_disposed && !_cancelled.contains(id)) {
        try {
          check();
        } catch (policyError) {
          failure = policyError;
        }
      }
      t['status'] = _disposed
          ? 'interrupted'
          : _cancelled.contains(id)
          ? 'cancelled'
          : 'failed';
      t['error'] = failure is ToolFailure
          ? failure.code
          : failure is PluginException
          ? failure.code
          : 'transfer_failed';
    } finally {
      _downloads.remove(id)?.cancel();
      _writes.remove(id);
      // Keep only an interrupted/failed cache for an explicit Range retry.
      // Successful and cancelled jobs never retain temporary media.
      if (cache != null && (succeeded || _cancelled.contains(id))) {
        try {
          if (await cache.exists()) await cache.delete();
        } catch (_) {}
      }
      _emit(id);
    }
  }

  /// Keep task control available on hosts without the media processor.
  void registerFallbackTaskTools(
    ToolRegistry registry,
    bool Function() accepting,
  ) {
    void add(
      String name,
      String description,
      Map<String, ToolField> fields,
      Future<Map<String, dynamic>> Function(Map<String, dynamic>) run, {
      bool readOnly = true,
    }) {
      if (registry[name] != null) return;
      registry.register(
        RegisteredTool(
          name,
          description,
          fields,
          run,
          readOnly: readOnly,
          timeout: TaskWait.toolTimeout,
        ),
      );
    }

    const id = ToolField('string', required: true, maxLength: 64);
    add(
      'task_get',
      'Get a background file transfer; optionally wait up to 120 seconds.',
      {'task_id': id, 'wait_seconds': TaskWait.field},
      (a) => TaskWait.until(
        taskId: a['task_id'] as String,
        read: () => task(a['task_id'] as String),
        changes: changes,
        seconds: a['wait_seconds'] as int? ?? 0,
      ),
    );
    add(
      'task_list',
      'List recent background file transfers.',
      {
        'offset': const ToolField('integer', minimum: 0, maximum: 10000),
        'limit': const ToolField('integer', minimum: 1, maximum: 20),
      },
      (a) async {
        final offset = a['offset'] as int? ?? 0;
        final limit = a['limit'] as int? ?? 10;
        final rows = tasks().skip(offset).take(limit).toList();
        return {
          'tasks': rows,
          'next_offset': rows.length == limit ? offset + limit : null,
        };
      },
    );
    add(
      'task_cancel',
      'Cancel a background file transfer.',
      {'task_id': id},
      (a) async => cancel(a['task_id'] as String),
      readOnly: false,
    );
    add(
      'task_retry',
      'Resume an interrupted cached download or retry a failed transfer.',
      {'task_id': id},
      (a) async {
        if (!ToolExecution.active || !accepting()) {
          throw const ToolFailure('cancelled');
        }
        return retry(a['task_id'] as String);
      },
      readOnly: false,
    );
  }

  /// Only this feature's private files are eligible for orphan/age cleanup.
  Future<void> _cleanCache(Directory dir, String activeId) async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!RegExp(r'^transfer-[0-9]+-[0-9]+\.part$').hasMatch(name)) continue;
      final id = name.substring(0, name.length - 5);
      if (id == activeId) continue;
      final task = _tasks[id];
      if (task != null &&
          {'queued', 'running', 'cancelling'}.contains(task['status'])) {
        continue;
      }
      if (task == null ||
          {'succeeded', 'cancelled'}.contains(task['status']) ||
          (await entity.stat()).modified.isBefore(cutoff)) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> dispose() async {
    for (final t in _tasks.values) {
      if ({'queued', 'running', 'cancelling'}.contains(t['status'])) {
        t['status'] = 'interrupted';
        _emit(t['task_id'] as String);
      }
    }
    _disposed = true;
    for (final d in _downloads.values) {
      d.cancel();
    }
    for (final w in _writes.values) {
      w.cancel();
    }
    await _queue;
    await _changes.close();
  }
}
