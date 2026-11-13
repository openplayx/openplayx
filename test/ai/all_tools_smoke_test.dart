import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/services/ai_tools/media_tools.dart';
import 'package:openplayx/services/ai_tools/tool_registry.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:sqlite3/sqlite3.dart';

class FakeSources extends SourceManager {
  @override
  List<SourceConfig> get configs => [
    SourceConfig(
      id: 's1',
      name: 'Jelly',
      kind: SourceKind.jellyfin,
      address: 'https://private.test/',
    ),
  ];
  @override
  Future<void> load() async {}
  final folder = const SourceEntry(
    ResourceRef('s1', '/dir'),
    'Dir',
    isFolder: true,
  );
  final file = const SourceEntry(
    ResourceRef('s1', '/dir/film.mp4'),
    'Film',
    isFolder: false,
  );
  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) async =>
      BrowseResult(request.node == null ? [folder] : [file]);
  @override
  Future<BrowseResult> search(
    String id,
    String query, {
    int offset = 0,
    int limit = 20,
  }) async => BrowseResult([file]);
}

void main() {
  test('every registered agent tool succeeds through the gateway', () async {
    final library = LibraryService(sqlite3.openInMemory());
    addTearDown(library.close);
    final media = library.register(
      const SourceEntry(
        ResourceRef('@local', '/private/film.mp4'),
        'Film',
        isFolder: false,
      ),
    );
    final lib = library.create('Movies');
    library.db.execute('INSERT INTO memberships VALUES (?,?,?)', [
      lib,
      media,
      1,
    ]);
    final resource = library.resources(media).single['id'] as String;
    final session = library.beginSession(resource);
    library.saveProgress(
      resource,
      session,
      const Duration(minutes: 5),
      const Duration(minutes: 90),
    );

    final controls = <String>[];
    final snapshot = {'session_id': 'p1', 'status': 'playing'};
    final tools = MediaTools(
      library: library,
      sources: FakeSources(),
      context: () => {'page': 'home'},
      canExecute: () => true,
      playbackSnapshot: () => snapshot,
      playbackControl: (cmd, args) async {
        controls.add(cmd);
        return snapshot;
      },
      openResource: (entry) async => {'command_status': 'submitted'},
    );
    final gateway = ToolGateway(tools.registry);
    final allowed = tools.registry.available.map((t) => t.name).toSet();
    var n = 0;
    final results = <String, ToolResult>{};
    Future<ToolResult> call(String name, Map<String, dynamic> args) async {
      final r = await gateway.invoke(
        turn: 'turn',
        call: ModelToolCall('c${n++}', name, jsonEncode(args)),
        allowed: allowed,
        active: () => true,
        confirm: (_, _) async => true,
      );
      results[name] = r;
      return r;
    }

    await call('context_get', {});
    await call('source_list', {});
    final root = await call('source_browse', {'source_id': 's1'});
    final folderRef = (root.data['entries'] as List).single['ref'];
    final inner = await call('source_browse', {
      'source_id': 's1',
      'folder_ref': folderRef,
    });
    final fileRef = (inner.data['entries'] as List).single['ref'];
    await call('library_list', {});
    await call('library_query', {'query': 'Film'});
    await call('media_get', {'media_id': media});
    await call('search_media', {'query': 'Film'});
    await call('progress_query', {});
    await call('media_set_favorite', {'media_id': media, 'favorite': true});
    await call('playback_get', {});
    await call('playback_open', {'ref': fileRef});
    results['playback_open(resource_id)'] = await call('playback_open', {
      'resource_id': resource,
    });
    await call('playback_pause', {'session_id': 'p1'});
    await call('playback_resume', {'session_id': 'p1'});
    await call('playback_seek', {'session_id': 'p1', 'position_ms': 1000});
    await call('playback_set_speed', {'session_id': 'p1', 'speed': 1.5});
    await call('playback_set_volume', {'session_id': 'p1', 'volume': 50});
    await call('playback_stop', {'session_id': 'p1'});

    for (final e in results.entries) {
      // ignore: avoid_print
      print('${e.key.padRight(28)} ${e.value.status} '
          '${e.value.error ?? ''} ${jsonEncode(e.value.data)}');
    }
    final missing = allowed.difference(results.keys.toSet());
    expect(missing, isEmpty, reason: 'untested tools: $missing');
    expect(
      results.entries.where((e) => e.value.status != 'success').map((e) => e.key),
      isEmpty,
    );
    expect(library.db.select('SELECT favorite FROM media').single['favorite'], 1);
    expect(controls, ['pause', 'resume', 'seek', 'set_speed', 'set_volume', 'stop']);
    expect((results['progress_query']!.data['progress'] as List), isNotEmpty);
  });
}
