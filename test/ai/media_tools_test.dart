import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/services/ai_tools/media_tools.dart';
import 'package:openplayx/services/ai_tools/tool_registry.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:sqlite3/sqlite3.dart';

class SearchSources extends SourceManager {
  final enabled = <String>{'1', '2', '3', '4', '5'};
  int active = 0;
  int maxActive = 0;
  @override
  List<SourceConfig> get configs => [
    for (final id in enabled)
      SourceConfig(
        id: id,
        name: 'Provider $id',
        kind: SourceKind.jellyfin,
        address: 'https://private.test/?token=SECRET',
      ),
  ];
  @override
  SourceBindings get bindings =>
      const SourceBindings(searchInstances: ['1', '2', '3', '4', '5']);
  @override
  Future<void> load() async {}
  @override
  Future<BrowseResult> search(
    String id,
    String query, {
    int offset = 0,
    int limit = 20,
  }) async {
    active++;
    if (active > maxActive) maxActive = active;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      if (id == '2') throw StateError('SECRET');
      return BrowseResult([
        SourceEntry(
          ResourceRef(id, '/PRIVATE/film.mp4'),
          'Film',
          isFolder: false,
        ),
      ], nextOffset: 20);
    } finally {
      active--;
    }
  }
}

void main() {
  test('multi-provider search has bounded concurrency, per-source errors, opaque refs and live availability', () async {
    final library = LibraryService(sqlite3.openInMemory());
    addTearDown(library.close);
    final sources = SearchSources();
    final catalog = MediaTools(
      library: library,
      sources: sources,
      context: () => {},
    );
    final gateway = ToolGateway(catalog.registry);
    Future<ToolResult> call(String name, Map<String, dynamic> args) =>
        gateway.invoke(
          turn: 'turn',
          call: ModelToolCall('call', name, jsonEncode(args)),
          allowed: catalog.registry.available.map((t) => t.name).toSet(),
          active: () => true,
          confirm: (_, _) async => true,
        );
    final result = await call('search_media', {'query': 'Film'});
    final data = result.data['sources'] as List;
    expect(data.length, 5);
    expect(sources.maxActive, 3);
    expect(data.where((r) => r['error_code'] != null).length, 1);
    expect(jsonEncode(result.toJson()), isNot(contains('PRIVATE')));
    expect(jsonEncode(result.toJson()), isNot(contains('SECRET')));
    final ref = data.first['entries'][0]['ref'];
    sources.enabled.remove('1');
    final unavailable = await call('source_browse', {
      'source_id': '1',
      'folder_ref': ref,
    });
    expect(unavailable.error, 'unavailable');
    final unknown = await call('source_browse', {
      'source_id': '3',
      'folder_ref': '/etc/passwd',
    });
    expect(unknown.error, 'staleReference');
  });

  test('library query and media_get use real business state without exposing local locators', () async {
    final library = LibraryService(sqlite3.openInMemory());
    addTearDown(library.close);
    final id = library.register(
      const SourceEntry(
        ResourceRef('@local', '/private/film.mp4'),
        'Film',
        isFolder: false,
      ),
    );
    final lib = library.create('Movies');
    library.db.execute('INSERT INTO memberships VALUES (?,?,?)', [lib, id, 1]);
    final catalog = MediaTools(
      library: library,
      sources: SearchSources(),
      context: () => {},
    );
    final query = await catalog.registry['library_query']!.execute({
      'query': 'Film',
    });
    expect((query['media'] as List).single['media_id'], id);
    final detail = await catalog.registry['media_get']!.execute({
      'media_id': id,
    });
    expect((detail['resources'] as List).single['resource_id'], isNotEmpty);
    expect(jsonEncode(detail), isNot(contains('/private/')));
    expect(
      catalog.registry.available.any((t) => t.name == 'subtitle_generate'),
      false,
    );
    expect(
      catalog.registry.available.any((t) => t.name == 'playback_open'),
      false,
    );
  });
}
