import 'dart:math';

import '../../core/plugins/plugin_gate.dart';
import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_manager.dart';
import '../../data/sources/source_schema.dart';
import '../library/library_service.dart';
import 'tool_registry.dart';

/// Opaque references keep local paths, server locators and resolved URLs on host.
class MediaTools {
  MediaTools({
    required this.library,
    required this.sources,
    required this.context,
    this.playbackSnapshot,
    this.playbackControl,
    this.openResource,
    this.canExecute,
  }) {
    _register();
  }
  final LibraryService library;
  final SourceManager sources;
  final Map<String, dynamic> Function() context;
  final Map<String, dynamic> Function()? playbackSnapshot;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  playbackControl;
  final Future<Map<String, dynamic>> Function(SourceEntry)? openResource;
  final bool Function()? canExecute;
  final registry = ToolRegistry();
  final _refs = <String, SourceEntry>{};
  SourceEntry? entryForReference(String ref) => _refs[ref];
  static const _id = ToolField('string', required: true);
  static const _offset = ToolField('integer', minimum: 0, maximum: 10000);
  static const _limit = ToolField('integer', minimum: 1, maximum: 20);
  static String safeText(String text) {
    var value = text.replaceAll(
      RegExp(r'https?://\S+', caseSensitive: false),
      '[地址已隐藏]',
    );
    if (value.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value)) {
      value = value.replaceAll('\\', '/').split('/').last;
    }
    return value.substring(0, min(200, value.length));
  }

  Map<String, dynamic> _media(Map<String, dynamic> row) => {
    'media_id': row['id'],
    'title': safeText(row['title'] as String),
    'favorite': row['favorite'] == 1,
  };

  /// Instance enabled, its plugin enabled, and the user's AI scope allows
  /// [capability] on it. Checked on every call, not when tools were listed.
  bool _enabled(String id, [String capability = 'source.browse']) {
    if (!ToolExecution.active || !(canExecute?.call() ?? true)) return false;
    final config = sources.configs
        .where((s) => s.id == id && s.enabled)
        .firstOrNull;
    return config != null &&
        PluginGate.ai(config.pluginId, instanceId: id, capability: capability);
  }

  /// Issues a `ref` for an entry, like browse/search results.
  Map<String, dynamic> issueReference(SourceEntry entry) => _entry(entry);

  Map<String, dynamic> _entry(SourceEntry entry) {
    if (_refs.length >= 2000) _refs.remove(_refs.keys.first);
    final token = 'ref-${Random.secure().nextInt(1 << 32)}-${_refs.length}';
    _refs[token] = entry;
    return {
      'ref': token,
      'source_id': entry.ref.instanceId,
      'title': safeText(entry.name),
      'is_folder': entry.isFolder,
    };
  }

  List<Map<String, dynamic>> _rows(Iterable<Map<String, dynamic>> rows) =>
      rows.map(_media).toList();
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
      execute,
      readOnly: readOnly,
      confirmation: confirmation,
    ),
  );
  void _register() {
    _add(
      'context_get',
      'Get the current sanitized page and playback context.',
      {},
      (_) async => context(),
    );
    _add(
      'source_list',
      'List enabled sources without addresses or credentials.',
      {},
      (_) async {
        await sources.load();
        return {
          'sources': [
            for (final s in sources.configs.where(
              (c) =>
                  c.enabled &&
                  PluginGate.ai(
                    c.pluginId,
                    instanceId: c.id,
                    capability: 'source.browse',
                  ),
            ))
              {
                'source_id': s.id,
                'name': safeText(s.name),
                'kind': s.kind.name,
                'searchable': SourceSchemas.forKind(s.kind).capabilities
                    .contains('search.media'),
              },
          ],
        };
      },
    );
    _add(
      'source_browse',
      'Browse an enabled source. Use only returned folder_ref values; omit for root.',
      {
        'source_id': _id,
        'folder_ref': const ToolField('string'),
        'offset': _offset,
        'limit': _limit,
      },
      (a) async {
        await sources.load();
        final source = a['source_id'] as String;
        if (!_enabled(source)) throw const ToolFailure('unavailable');
        final folder = a['folder_ref'] == null ? null : _refs[a['folder_ref']];
        if (a['folder_ref'] != null &&
            (folder == null ||
                !folder.isFolder ||
                folder.ref.instanceId != source)) {
          throw const ToolFailure('staleReference');
        }
        final page = await sources.browse(
          source,
          BrowseRequest(
            node: folder?.ref,
            offset: a['offset'] as int? ?? 0,
            limit: a['limit'] as int? ?? 20,
          ),
        );
        if (!_enabled(source)) throw const ToolFailure('unavailable');
        return {
          'entries': page.entries.map(_entry).toList(),
          'next_offset': page.nextOffset,
        };
      },
    );
    _add(
      'library_list',
      'List accessible media libraries.',
      {},
      (_) async => {
        'libraries': [
          for (final row in library.libraries.take(40))
            {
              'library_id': row['id'],
              'name': safeText(row['name'] as String),
              'type': row['type'],
            },
        ],
      },
    );
    _add(
      'library_query',
      'Query real library media with filters and pagination.',
      {
        'library_id': const ToolField('string'),
        'query': const ToolField('string'),
        'watched': const ToolField('boolean'),
        'favorites': const ToolField('boolean'),
        'year': const ToolField('integer', minimum: 1800, maximum: 2200),
        'offset': _offset,
        'limit': _limit,
      },
      (a) async {
        final offset = a['offset'] as int? ?? 0;
        final limit = a['limit'] as int? ?? 20;
        final rows = library.query(
          a['library_id'] as String?,
          search: a['query'] as String? ?? '',
          watched: a['watched'] as bool?,
          favorites: a['favorites'] == true,
          year: a['year'] as int?,
          offset: offset,
          limit: limit,
        );
        return {
          'media': _rows(rows),
          'next_offset': rows.length == limit ? offset + limit : null,
        };
      },
    );
    _add(
      'media_get',
      'Get media and registered resource IDs, without file locations.',
      {'media_id': _id},
      (a) async {
        final rows = library.db.select(
          'SELECT id,title,favorite FROM media WHERE id=?',
          [a['media_id']],
        );
        if (rows.isEmpty) throw const ToolFailure('notFound');
        return {
          ..._media(rows.first),
          'resources': [
            for (final r in library.resources(a['media_id'] as String).take(20))
              if (r['source'] == '@local' ||
                  _enabled(r['source'] as String, 'source.resolve'))
                {
                  'resource_id': r['id'],
                  'name': safeText(r['name'] as String),
                  'source_id': r['source'],
                },
          ],
        };
      },
    );
    _add(
      'search_media',
      'Search library and all search-enabled sources, preserving per-source pages and partial errors.',
      {'query': _id, 'offset': _offset, 'limit': _limit},
      (a) async {
        await sources.load();
        final query = a['query'] as String;
        final offset = a['offset'] as int? ?? 0;
        final limit = a['limit'] as int? ?? 20;
        final local = library.query(
          null,
          search: query,
          offset: offset,
          limit: limit,
        );
        final providers = sources.configs
            .where(
              (s) =>
                  s.enabled &&
                  SourceSchemas.forKind(s.kind).capabilities
                      .contains('search.media') &&
                  PluginGate.ai(
                    s.pluginId,
                    instanceId: s.id,
                    capability: 'search.media',
                  ),
            )
            .take(12)
            .toList();
        final results = <Map<String, dynamic>>[];
        // Bounded concurrency: a failed provider cannot discard other results.
        for (var start = 0; start < providers.length; start += 3) {
          if (!ToolExecution.active || !(canExecute?.call() ?? true)) {
            throw const ToolFailure('cancelled');
          }
          results.addAll(
            await Future.wait(
              providers.skip(start).take(3).map((source) async {
                try {
                  final page = await sources.search(
                    source.id,
                    query,
                    offset: offset,
                    limit: limit,
                  );
                  if (!_enabled(source.id, 'search.media')) {
                    throw const ToolFailure('unavailable');
                  }
                  return {
                    'source_id': source.id,
                    'entries': page.entries.map(_entry).toList(),
                    'next_offset': page.nextOffset,
                  };
                } catch (_) {
                  return <String, dynamic>{
                    'source_id': source.id,
                    'error_code': 'sourceUnavailable',
                  };
                }
              }),
            ),
          );
        }
        return {
          'library': _rows(local),
          'library_next_offset': local.length == limit ? offset + limit : null,
          'sources': results,
        };
      },
    );
    _add(
      'progress_query',
      'Get actual unfinished viewing progress. Use media_get before opening exact resource.',
      {},
      (_) async => {
        'progress': [
          for (final row in library.continueWatching(limit: 20))
            {
              ..._media(row),
              'resource_id': row['resource_id'],
              'position_ms': row['position'],
              'duration_ms': row['duration'],
            },
        ],
      },
    );
    _add(
      'media_set_favorite',
      'Set favorite state for an explicit media item; asks for confirmation.',
      {'media_id': _id, 'favorite': const ToolField('boolean', required: true)},
      (a) async {
        final id = a['media_id'] as String;
        if (library.db.select('SELECT id FROM media WHERE id=?', [
          id,
        ]).isEmpty) {
          throw const ToolFailure('notFound');
        }
        library.favorite(id, a['favorite'] as bool);
        return {'media_id': id, 'favorite': a['favorite']};
      },
      readOnly: false,
      confirmation: true,
    );
    if (playbackSnapshot != null) {
      _add(
        'playback_get',
        'Get the real playback session and available controls.',
        {},
        (_) async => playbackSnapshot!(),
      );
    }
    if (openResource != null) {
      _add(
        'playback_open',
        'Open an exact resource_id from media_get, or non-folder ref from search/browse. Specify exactly one.',
        {
          'resource_id': const ToolField('string'),
          'ref': const ToolField('string'),
        },
        (a) async {
          if ((a['resource_id'] == null) == (a['ref'] == null)) {
            throw const ToolFailure('ambiguousTarget');
          }
          SourceEntry? entry;
          if (a['ref'] != null) {
            entry = _refs[a['ref']];
          } else {
            final rows = library.db.select(
              'SELECT * FROM resources WHERE id=?',
              [a['resource_id']],
            );
            if (rows.isNotEmpty) {
              final r = rows.first;
              entry = SourceEntry(
                ResourceRef(r['source'] as String, r['item'] as String),
                r['name'] as String,
                isFolder: false,
              );
            }
          }
          if (entry == null || entry.isFolder) {
            throw const ToolFailure('staleReference');
          }
          if (entry.ref.instanceId != '@local' &&
              !_enabled(entry.ref.instanceId, 'source.resolve')) {
            throw const ToolFailure('unavailable');
          }
          return openResource!(entry);
        },
        readOnly: false,
      );
    }
    if (playbackControl != null) {
      for (final name in [
        'pause',
        'resume',
        'stop',
        'seek',
        'set_speed',
        'set_volume',
        'set_subtitle',
      ]) {
        _add(
          'playback_$name',
          name == 'set_subtitle'
              ? 'Show a saved recognised subtitle in the exact current session: binding_id from subtitle_save (omit for the newest saved one for this video), or off=true to hide subtitles. Use only when the user asked for it.'
              : 'Control only the exact current session; reject stale sessions.',
          {
            'session_id': _id,
            if (name == 'seek')
              'position_ms': const ToolField(
                'integer',
                required: true,
                minimum: 0,
              ),
            if (name == 'set_speed')
              'speed': const ToolField(
                'number',
                required: true,
                minimum: 0.25,
                maximum: 4,
              ),
            if (name == 'set_volume')
              'volume': const ToolField(
                'integer',
                required: true,
                minimum: 0,
                maximum: 100,
              ),
            if (name == 'set_subtitle') ...{
              'binding_id': const ToolField('string', maxLength: 64),
              'off': const ToolField('boolean'),
            },
          },
          (a) => playbackControl!(name, a),
          readOnly: false,
        );
      }
    }
  }
}
