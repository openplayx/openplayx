import 'dart:math';

import '../torrent/torrent_service.dart';
import 'tool_registry.dart';
import '../../core/plugins/plugin_gate.dart';

/// Business tools over configured bittorrent-server instances. The model
/// only handles host-issued references (server_ref, task_ref, file_ref,
/// plan_ref, removal_ref, input_ref): never a base URL, token, server path
/// or raw engine option. Server downloads are reported as such; they are
/// not in the App library and not offline on this device.
class TorrentTools {
  TorrentTools({
    required this.registry,
    required this.store,
    this.userTexts,
    this.canExecute,
  }) {
    _register();
  }

  final ToolRegistry registry;
  final TorrentServiceStore store;

  /// User messages of the conversation; a magnet must come from the user.
  final Iterable<String> Function()? userTexts;
  final bool Function()? canExecute;

  final _tasks = <String, (String, String)>{}; // ref -> (server, task id)
  final _plans = <String, _PlanRef>{};
  final _files =
      <String, (String, String, String)>{}; // ref -> (server, task, file id)
  final _removals = <String, _RemovalRef>{};
  final _inputs = <String, _InputRef>{};
  final _names = <String, String>{}; // task ref -> display name
  final _random = Random.secure();

  static const _taskRef = ToolField('string', required: true, maxLength: 64);
  static const _serverRef = ToolField('string', maxLength: 64);

  String _token(String prefix, Map<String, Object> map) {
    if (map.length >= 2000) map.remove(map.keys.first);
    return '$prefix-${_random.nextInt(1 << 32).toRadixString(36)}${map.length.toRadixString(36)}';
  }

  String _issueTask(String server, String id, [String? name]) {
    final existing = _tasks.entries
        .where((e) => e.value == (server, id))
        .firstOrNull;
    final ref = existing?.key ?? _token('task', _tasks);
    _tasks[ref] = (server, id);
    if (name != null) _names[ref] = name;
    return ref;
  }

  String _issueFile(String server, String task, String fileId) {
    final existing = _files.entries
        .where((e) => e.value == (server, task, fileId))
        .firstOrNull;
    if (existing != null) return existing.key;
    final ref = _token('file', _files);
    _files[ref] = (server, task, fileId);
    return ref;
  }

  /// Called by the settings page after the user uploads a .torrent file.
  String registerUpload(String server, Map<String, dynamic> input) {
    final ref = _token('upload', _inputs);
    _inputs[ref] = _InputRef(
      server,
      input['input_ref'] as String,
      '${input['name'] ?? ''}',
      (input['total_size'] as num?)?.toInt() ?? 0,
      DateTime.tryParse('${input['expires_at']}') ??
          DateTime.now().add(const Duration(minutes: 30)),
    );
    return ref;
  }

  List<Map<String, dynamic>> get uploads => [
    for (final e in _inputs.entries)
      if (e.value.expires.isAfter(DateTime.now()))
        {
          'input_ref': e.key,
          'server_ref': e.value.server,
          'name': e.value.name,
          'total_size': e.value.size,
        },
  ];

  // Offered only when a server is configured, so users without one keep
  // the same tool set.
  bool get _available => _servers.isNotEmpty;

  /// Servers the AI may use: enabled, plugin enabled, and in the user's AI
  /// instance scope. Traditional pages use the store directly.
  List<TorrentServiceConfig> get _servers => [
    for (final c in store.enabled)
      if (PluginGate.ai(TorrentServiceStore.pluginId, instanceId: c.id)) c,
  ];

  TorrentServiceConfig _server(Object? ref) {
    final enabled = _servers;
    if (ref == null) {
      if (enabled.length == 1) return enabled.single;
      throw ToolFailure(
        enabled.isEmpty ? 'serviceNotConfigured' : 'ambiguousServer',
      );
    }
    return enabled.where((c) => c.id == ref).firstOrNull ??
        (throw const ToolFailure('staleReference'));
  }

  (TorrentServiceConfig, String, String) _task(Object? ref) {
    final t = _tasks[ref];
    if (t == null) throw const ToolFailure('staleReference');
    return (_server(t.$1), t.$2, ref as String);
  }

  Future<Map<String, dynamic>> _guard(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    if (!(canExecute?.call() ?? true) || !ToolExecution.active) {
      throw const ToolFailure('cancelled');
    }
    try {
      return await action();
    } on TorrentServiceException catch (e) {
      throw ToolFailure(e.code);
    }
  }

  void _add(
    String name,
    String description,
    Map<String, ToolField> fields,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>) execute, {
    bool readOnly = true,
    bool confirmation = false,
  }) => registry.register(
    RegisteredTool(
      name,
      description,
      fields,
      (a) => _guard(() => execute(a)),
      readOnly: readOnly,
      confirmation: confirmation,
      available: () => _available,
    ),
  );

  /// Explicit field allowlist for the model and the chat task card.
  Map<String, dynamic> _project(TorrentServiceConfig server, Map task) {
    final ref = _issueTask(
      server.id,
      task['id'] as String,
      task['name'] as String?,
    );
    double round(Object? v) => ((v as num? ?? 0) * 1000).round() / 1000;
    return {
      'task_ref': ref,
      'server_ref': server.id,
      'server_name': server.name,
      'location': 'server',
      'added_via': task['added_via'],
      'name': _safe(task['name']),
      'state': task['state'],
      'hold_reason': ?task['hold_reason'],
      'error_code': ?task['error_code'],
      'progress': round(task['progress']),
      'selected_size': task['selected_size'],
      'total_size': task['total_size'],
      'download_speed': task['download_speed'],
      'upload_speed': task['upload_speed'],
      'eta_seconds': ?task['eta_seconds'],
      'metadata_known': task['metadata_known'],
      'selected_files_complete': task['selected_files_complete'],
      'payload_complete': task['payload_complete'],
      'seeding': task['seeding'],
      'stale': task['stale'],
      'engine_status': task['engine_status'],
      // Completing on the server is not "in the App" or "on this device".
      'in_app_library': false,
      'offline_on_device': false,
    };
  }

  static String _safe(Object? v) {
    final s = '${v ?? ''}'.replaceAll(RegExp(r'[\x00-\x1f]'), '');
    return s.length > 200 ? s.substring(0, 200) : s;
  }

  /// Info hash as written by the user (hex or base32), for provenance.
  static String? _magnetHash(String magnet) {
    final m = RegExp(r'xt=urn:bt(?:ih|mh):([0-9a-zA-Z]{32,68})')
        .firstMatch(magnet);
    return m?.group(1)?.toLowerCase();
  }

  String? describe(String tool, Map<String, dynamic> args) {
    switch (tool) {
      case 'torrent_remove':
        final r = _removals[args['removal_ref']];
        if (r == null) return null;
        final size = (r.bytes / (1 << 20)).toStringAsFixed(1);
        return r.deleteFiles
            ? '移除服务器下载「${r.name}」并删除已下载文件（$size MB）'
            : '移除服务器下载「${r.name}」，保留已下载文件';
      case 'torrent_select_files':
        final name = _names[args['task_ref']];
        return name == null ? null : '更改服务器下载「$name」的下载文件';
    }
    return null;
  }

  void _register() {
    _add(
      'torrent_service_info',
      'List configured BitTorrent servers (server_ref), their engine status, destinations, limits, '
          'and .torrent files the user uploaded in settings (input_ref). Downloads run on the server, '
          'not on this device.',
      {'server_ref': _serverRef},
      (a) async {
        final servers = a['server_ref'] == null
            ? _servers
            : [_server(a['server_ref'])];
        final out = <Map<String, dynamic>>[];
        for (final s in servers) {
          try {
            final caps = await (await store.client(s.id)).capabilities();
            final engine = caps['engine'] as Map? ?? const {};
            out.add({
              'server_ref': s.id,
              'name': s.name,
              'available': engine['available'] == true,
              'engine_version': engine['version'],
              'inputs': caps['inputs'],
              'selection_presets': caps['selection_presets'],
              'file_content': caps['file_content'],
              'default_destination': s.defaultDestination,
              'delete_files_allowed': s.allowDeleteFiles,
              'destinations': [
                for (final d in (caps['destinations'] as List? ?? const []))
                  {
                    'destination_ref': (d as Map)['destination_ref'],
                    'name': d['name'],
                    'free_bytes': ?d['free_bytes'],
                  },
              ],
              'limits': caps['limits'],
            });
          } on TorrentServiceException catch (e) {
            out.add({
              'server_ref': s.id,
              'name': s.name,
              'available': false,
              'error_code': e.code,
            });
          }
        }
        return {'servers': out, 'uploaded_inputs': uploads};
      },
    );

    _add(
      'torrent_plan',
      'Preview a server download for a magnet link the user explicitly gave in this conversation, '
          'or an input_ref from torrent_service_info. Specify exactly one. Contacts no peers; returns '
          'plan_ref for torrent_add. Never invent or search for magnets.',
      {
        'server_ref': _serverRef,
        'magnet': const ToolField('string', maxLength: 4096),
        'input_ref': const ToolField('string', maxLength: 64),
        'destination_ref': const ToolField('string', maxLength: 64),
        'selection_preset': const ToolField('string', values: ['all', 'video']),
        'auto_start': const ToolField('boolean'),
      },
      (a) async {
        final magnet = a['magnet'] as String?,
            input = a['input_ref'] as String?;
        if ((magnet == null) == (input == null)) {
          throw const ToolFailure('ambiguousTarget');
        }
        TorrentServiceConfig server;
        Map<String, dynamic> source;
        if (magnet != null) {
          final hash = _magnetHash(magnet);
          final texts = userTexts?.call();
          if (hash == null ||
              (texts != null &&
                  !texts.any((t) => t.toLowerCase().contains(hash)))) {
            // Only magnets the user actually provided may be planned.
            throw const ToolFailure('magnetNotFromUser');
          }
          server = _server(a['server_ref']);
          source = {'type': 'magnet', 'magnet': magnet};
        } else {
          final up = _inputs[input];
          if (up == null || up.expires.isBefore(DateTime.now())) {
            throw const ToolFailure('staleReference');
          }
          server = _server(up.server);
          source = {'type': 'input', 'input_ref': up.serverRef};
        }
        final client = await store.client(server.id);
        try {
          final plan = await client.plan({
            'source': source,
            'destination_ref':
                a['destination_ref'] ?? server.defaultDestination,
            'selection_preset': a['selection_preset'] ?? 'all',
            'auto_start': a['auto_start'] ?? true,
          });
          final ref = _token('plan', _plans);
          _plans[ref] = _PlanRef(
            server.id,
            plan['plan_ref'] as String,
            _safe(plan['name']),
          );
          return {
            'plan_ref': ref,
            'server_ref': server.id,
            'name': _safe(plan['name']),
            'input_kind': plan['input_kind'],
            'torrent_version': plan['torrent_version'],
            'metadata': plan['metadata'],
            'total_size': ?plan['total_size'],
            'selected_size': ?plan['selected_size'],
            'file_count': ?plan['file_count'],
            'files_preview': [
              for (final f in (plan['files_preview'] as List? ?? const []).take(
                20,
              ))
                {
                  'path': _safe((f as Map)['path']),
                  'size': f['size'],
                  'selected': f['selected'],
                },
            ],
            'destination': (plan['destination'] as Map?)?['name'],
            'selection_preset': plan['selection_preset'],
            'auto_start': plan['auto_start'],
            'trackers': plan['trackers'],
            // Dropped by the server's network policy; the rest still works.
            'removed_addresses': ?plan['removed_addresses'],
            'warnings': plan['warnings'],
            'expires_at': plan['expires_at'],
          };
        } on TorrentServiceException catch (e) {
          if (e.code == 'duplicate_task' && e.detail?['task_id'] is String) {
            final task = await client.task(e.detail!['task_id'] as String);
            return {'status': 'already_exists', 'task': _project(server, task)};
          }
          rethrow;
        }
      },
    );

    _add(
      'torrent_add',
      'Start the server download described by a plan_ref. Returns task_ref immediately; the download '
          'continues on the server even if the App closes.',
      {'plan_ref': const ToolField('string', required: true, maxLength: 64)},
      (a) async {
        final plan = _plans[a['plan_ref']];
        if (plan == null) throw const ToolFailure('staleReference');
        final server = _server(plan.server);
        final client = await store.client(server.id);
        // Returns once the engine lists the torrent; repeating the same
        // plan returns the existing torrent.
        final task = await client.create(plan.serverRef);
        return {'status': 'created', 'task': _project(server, task)};
      },
      readOnly: false,
    );

    _add(
      'torrent_list',
      'List every download on the server, read live (including ones added in the WebUI; '
          'added_via tells them apart). All are controllable with their task_ref. Do not poll repeatedly.',
      {'server_ref': _serverRef},
      (a) async {
        final servers = a['server_ref'] == null
            ? _servers
            : [_server(a['server_ref'])];
        final tasks = <Map<String, dynamic>>[];
        final errors = <Map<String, dynamic>>[];
        for (final s in servers) {
          try {
            final client = await store.client(s.id);
            final list = await client.list();
            for (final t in (list['items'] as List)) {
              final m = t as Map;
              tasks.add(_project(s, m));
            }
          } on TorrentServiceException catch (e) {
            // Unreachable server: keep its tasks referenced, report the error.
            errors.add({
              'server_ref': s.id,
              'name': s.name,
              'error_code': e.code,
            });
          }
        }
        return {
          'torrent_tasks': tasks.take(50).toList(),
          if (tasks.length > 50) 'truncated': true,
          if (errors.isNotEmpty) 'server_errors': errors,
        };
      },
    );

    _add(
      'torrent_get',
      'Get one server download\'s state, progress, seeding and error.',
      {'task_ref': _taskRef},
      (a) async {
        final (server, id, _) = _task(a['task_ref']);
        final task = await (await store.client(server.id)).task(id);
        return {'torrent_task': _project(server, task)};
      },
    );

    _add(
      'torrent_files',
      'List files of a server download once metadata is known, with file_ref for selection.',
      {'task_ref': _taskRef},
      (a) async {
        final (server, id, ref) = _task(a['task_ref']);
        final f = await (await store.client(server.id)).files(id);
        final list = (f['files'] as List? ?? const []);
        return {
          'task_ref': ref,
          'metadata_known': f['metadata_known'],
          'files': [
            for (final x in list.take(100))
              {
                'file_ref': _issueFile(
                  server.id,
                  id,
                  (x as Map)['file_id'] as String,
                ),
                'path': _safe(x['path']),
                'size': x['size'],
                'progress': x['progress'],
                'selected': x['selected'],
                'complete': x['complete'],
                'is_video': x['is_video'],
              },
          ],
          if (list.length > 100) 'truncated': true,
        };
      },
    );

    _add(
      'torrent_select_files',
      'Change which files a server download fetches: a preset ("all", "video"), or one file_ref with '
          'action "only", "add" or "remove". Asks the user to confirm.',
      {
        'task_ref': _taskRef,
        'preset': const ToolField('string', values: ['all', 'video']),
        'file_ref': const ToolField('string', maxLength: 64),
        'action': const ToolField('string', values: ['only', 'add', 'remove']),
      },
      (a) async {
        final (server, id, ref) = _task(a['task_ref']);
        final preset = a['preset'] as String?,
            fileRef = a['file_ref'] as String?;
        if ((preset == null) == (fileRef == null)) {
          throw const ToolFailure('ambiguousTarget');
        }
        final client = await store.client(server.id);
        final files = await client.files(id);
        if (files['metadata_known'] != true) {
          throw const ToolFailure('metadata_pending');
        }
        final revision = files['files_revision'] as String;
        List<String>? ids;
        if (fileRef != null) {
          final f = _files[fileRef];
          if (f == null || f.$1 != server.id || f.$2 != id) {
            throw const ToolFailure('staleReference');
          }
          final current = {
            for (final x in files['files'] as List)
              if ((x as Map)['selected'] == true) x['file_id'] as String,
          };
          final set = switch (a['action'] ?? 'only') {
            'add' => {...current, f.$3},
            'remove' => current..remove(f.$3),
            _ => {f.$3},
          };
          if (set.isEmpty) throw const ToolFailure('empty_selection');
          ids = set.toList()..sort();
        }
        final after = await client.select(
          id,
          revision,
          preset: preset,
          fileIds: ids,
        );
        return {
          'task_ref': ref,
          'status': 'updated',
          'selected_count': (after['files'] as List)
              .where((f) => (f as Map)['selected'] == true)
              .length,
        };
      },
      readOnly: false,
      confirmation: true,
    );

    for (final action in ['pause', 'resume']) {
      _add(
        'torrent_$action',
        action == 'pause'
            ? 'Pause one explicit server download; succeeds once the server engine reports it stopped.'
            : 'Resume one explicit server download (never force-started).',
        {'task_ref': _taskRef},
        (a) async {
          final (server, id, ref) = _task(a['task_ref']);
          final client = await store.client(server.id);
          final task = action == 'pause'
              ? await client.pause(id)
              : await client.resume(id);
          return {'task_ref': ref, 'torrent_task': _project(server, task)};
        },
        readOnly: false,
      );
    }

    _add(
      'torrent_set_limits',
      'Set per-download rate limits in KiB/s within the administrator ceiling (0 = the ceiling or unlimited).',
      {
        'task_ref': _taskRef,
        'download_kib': const ToolField(
          'integer',
          required: true,
          minimum: 0,
          maximum: 10000000,
        ),
        'upload_kib': const ToolField(
          'integer',
          required: true,
          minimum: 0,
          maximum: 10000000,
        ),
      },
      (a) async {
        final (server, id, ref) = _task(a['task_ref']);
        final client = await store.client(server.id);
        final dl = (a['download_kib'] as int) * 1024,
            ul = (a['upload_kib'] as int) * 1024;
        final task = await client.limits(id, dl, ul);
        return {'task_ref': ref, 'torrent_task': _project(server, task)};
      },
      readOnly: false,
    );

    _add(
      'torrent_remove_preview',
      'Preview removing a server download: whether files are kept (default) or deleted, bytes on disk, '
          'and effects. Returns removal_ref for torrent_remove.',
      {'task_ref': _taskRef, 'delete_files': const ToolField('boolean')},
      (a) async {
        final (server, id, ref) = _task(a['task_ref']);
        final delete = a['delete_files'] == true;
        if (delete && !server.allowDeleteFiles) {
          throw const ToolFailure('deleteFilesNotAllowed');
        }
        final plan = await (await store.client(server.id))
            .removePlan(id, delete);
        final removal = _token('removal', _removals);
        _removals[removal] = _RemovalRef(
          server.id,
          id,
          plan['plan_ref'] as String,
          delete,
          _safe(plan['task_name']),
          (plan['bytes_on_disk'] as num?)?.toInt() ?? 0,
        );
        return {
          'removal_ref': removal,
          'task_ref': ref,
          'name': _safe(plan['task_name']),
          'delete_files': delete,
          'files_on_disk': plan['files_on_disk'],
          'bytes_on_disk': plan['bytes_on_disk'],
          'stops_seeding': plan['stops_seeding'],
          'effects': plan['effects'],
          // The App library is never changed by removing a server task.
          'app_library_effect': 'none',
          'expires_at': plan['expires_at'],
        };
      },
    );

    _add(
      'torrent_remove',
      'Apply a removal_ref from torrent_remove_preview. The user confirms in the App; do not ask them to '
          'type a confirmation.',
      {'removal_ref': const ToolField('string', required: true, maxLength: 64)},
      (a) async {
        final r = _removals[a['removal_ref']];
        if (r == null) throw const ToolFailure('staleReference');
        final server = _server(r.server);
        if (r.deleteFiles && !server.allowDeleteFiles) {
          throw const ToolFailure('deleteFilesNotAllowed');
        }
        final client = await store.client(server.id);
        final result = await client.remove(r.task, r.planRef);
        _removals.remove(a['removal_ref']);
        return {
          'status': 'removed',
          'name': r.name,
          'data_deleted': result['data_deleted'],
        };
      },
      readOnly: false,
      confirmation: true,
    );
  }
}

class _PlanRef {
  const _PlanRef(this.server, this.serverRef, this.name);
  final String server, serverRef, name;
}

class _RemovalRef {
  const _RemovalRef(
    this.server,
    this.task,
    this.planRef,
    this.deleteFiles,
    this.name,
    this.bytes,
  );
  final String server, task, planRef, name;
  final bool deleteFiles;
  final int bytes;
}

class _InputRef {
  const _InputRef(
    this.server,
    this.serverRef,
    this.name,
    this.size,
    this.expires,
  );
  final String server, serverRef, name;
  final int size;
  final DateTime expires;
}
