import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/core/plugins/metadata_capability.dart';
import 'package:openplayx/data/metadata/metadata_queue.dart';

class FakeSources extends SourceManager {
  bool fail = false;
  Future<BrowseResult> Function(BrowseRequest)? handler;
  List<SourceEntry> entries = [
    const SourceEntry(
      ResourceRef('s', '/film.mp4'),
      'Film.mp4',
      isFolder: false,
    ),
  ];
  @override
  List<SourceConfig> get configs => [
    const SourceConfig(
      id: 's',
      kind: SourceKind.local,
      name: 'Local',
      address: '/',
    ),
  ];
  @override
  Future<void> load() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) async {
    if (fail) throw const PluginException('offline', 'offline');
    return handler == null ? BrowseResult(entries) : handler!(request);
  }
}

void main() {
  late LibraryService service;
  late FakeSources sources;
  setUp(() {
    service = LibraryService(sqlite3.openInMemory());
    sources = FakeSources();
  });
  tearDown(() => service.close());
  test(
    'file sources are named, can be disabled and hide only their own media',
    () async {
      final a = service.addFileSource('s', root: '/a', name: 'Movies');
      final b = service.addFileSource('s', root: '/b');
      sources.entries = [
        const SourceEntry(
          ResourceRef('s', '/a/one.mp4'),
          'One.mp4',
          isFolder: false,
        ),
      ];
      await service.scan(a, sources);
      sources.entries = [
        const SourceEntry(
          ResourceRef('s', '/b/two.mp4'),
          'Two.mp4',
          isFolder: false,
        ),
      ];
      await service.scan(b, sources);
      expect(service.fileSources().map((r) => r['name']), ['Movies', null]);
      expect(service.query(), hasLength(2));
      service.setFileSourceEnabled(a, false);
      expect(service.query().single['title'], 'Two.mp4');
      expect(
        () => service.scan(a, sources),
        throwsA(isA<StateError>()),
        reason: 'disabled sources are not scanned',
      );
      // Manually kept titles stay visible even if their source is disabled.
      final one =
          service.db
                  .select("SELECT id FROM media WHERE title='One.mp4'")
                  .single['id']
              as String;
      service.addManual(one);
      expect(service.query(), hasLength(2));
      service.setFileSourceEnabled(a, true);
      service.renameFileSource(b, '  Shows ');
      expect(service.fileSources().last['name'], 'Shows');
      expect(() => service.renameFileSource(b, ' '), throwsArgumentError);
    },
  );
  test('hide removes a title from every library and can be restored', () {
    final media = service.register(sources.entries.first);
    service.addManual(media);
    service.addManual(media);
    service.hide(media);
    expect(service.query(), isEmpty);
    expect(service.db.select('SELECT * FROM resources'), hasLength(1));
    service.clearIgnored();
    expect(service.db.select('SELECT * FROM ignored'), isEmpty);
  });
  test(
    'all libraries deduplicate shared media and exclude unfiled playback',
    () {
      final shared = service.register(sources.entries.first);
      service.addManual(shared);
      service.addManual(shared);
      service.register(
        const SourceEntry(
          ResourceRef('s', '/unfiled.mp4'),
          'Unfiled',
          isFolder: false,
        ),
      );
      expect(service.query().map((r) => r['id']), [shared]);
      expect(service.query().map((r) => r['id']), [shared]);
    },
  );

  test(
    'recent playback includes completed media and keeps the latest resource',
    () {
      final media = service.register(sources.entries.first);
      final resource = service.resources(media).single['id'] as String;
      service.saveProgress(
        resource,
        service.beginSession(resource),
        const Duration(minutes: 10),
        const Duration(minutes: 10),
        completed: true,
      );
      expect(service.continueWatching(), isEmpty);
      expect(service.recentlyPlayed().single['id'], media);
      service.beginSession(resource);
      expect(service.recentlyPlayed(), hasLength(1));
    },
  );
  test('direct identity is reused, repeated scans and multiple libraries share media', () async {
    final media = service.register(sources.entries.first);
    expect(service.query(), isEmpty);
    final binding = service.addFileSource('s');
    await service.scan(binding, sources);
    await service.scan(binding, sources);
    await service.scan(service.addFileSource('s'), sources);
    expect(service.query().single['id'], media);
    service.favorite(media, true);
    expect(service.query(favorites: true).single['id'], media);
    service.rename(media, 'User title');
    await service.scan(binding, sources);
    expect(service.query().single['title'], 'User title');
  });
  test('failed scan retains availability; completed empty scan marks unavailable without deletion', () async {
    final binding = service.addFileSource('s');
    await service.scan(binding, sources);
    sources.fail = true;
    await expectLater(
      service.scan(binding, sources),
      throwsA(isA<PluginException>()),
    );
    expect(service.query(), hasLength(1));
    expect(
      service.db.select('SELECT available FROM evidence').single['available'],
      1,
    );
    sources.fail = false;
    sources.entries = [];
    await service.scan(binding, sources);
    expect(
      service.db.select('SELECT available FROM evidence').single['available'],
      0,
    );
    expect(service.query(), hasLength(1));
  });
  test(
    'removal persists across scan and deletion preserves media and favorites',
    () async {
      final binding = service.addFileSource('s');
      await service.scan(binding, sources);
      final media = service.query().single['id'] as String;
      service.favorite(media, true);
      service.hide(media);
      await service.scan(binding, sources);
      expect(service.query(), isEmpty);
      service.clearIgnored();
      await service.scan(binding, sources);
      expect(service.query(), hasLength(1));
      service.removeFileSource(binding);
      expect(service.resources(media), hasLength(1));
      expect(
        service.db.select('SELECT favorite FROM media').single['favorite'],
        1,
      );
    },
  );
  test('stable pagination and literal search', () async {
    final binding = service.addFileSource('s');
    sources.entries = List.generate(
      45,
      (i) => SourceEntry(
        ResourceRef('s', '/$i.mp4'),
        'film $i.mp4',
        isFolder: false,
      ),
    );
    await service.scan(binding, sources);
    final first = service.query();
    final second = service.query(offset: 40);
    expect(first, hasLength(40));
    expect(second, hasLength(5));
    expect(
      first
          .map((r) => r['id'])
          .toSet()
          .intersection(second.map((r) => r['id']).toSet()),
      isEmpty,
    );
    expect(service.query(search: '%'), isEmpty);
  });
  test('direct local identity preserves the exact resource timeline across locators', () async {
    const direct = SourceEntry(
      ResourceRef('@local', '/film.mp4'),
      'Film.mp4',
      isFolder: false,
    );
    final media = service.register(direct, localPath: '/film.mp4');
    final resource = service.resourceFor(direct.ref)!['id'] as String;
    final session = service.beginSession(resource);
    service.saveProgress(
      resource,
      session,
      const Duration(seconds: 90),
      const Duration(minutes: 10),
    );
    await service.scan(service.addFileSource('s'), sources);
    expect(service.query().single['id'], media);
    expect(service.resourceFor(sources.entries.first.ref)!['id'], resource);
    expect(service.checkpoint(resource)!['position'], 90000);
    expect(service.resources(media), hasLength(2));
  });
  test('new session rejects stale checkpoints and permits rewinding', () {
    final media = service.register(sources.entries.first);
    final resource = service.resources(media).single['id'] as String;
    final old = service.beginSession(resource);
    service.saveProgress(
      resource,
      old,
      const Duration(minutes: 5),
      const Duration(minutes: 10),
    );
    final current = service.beginSession(resource);
    service.saveProgress(
      resource,
      current,
      const Duration(minutes: 2),
      const Duration(minutes: 10),
    );
    service.saveProgress(
      resource,
      old,
      const Duration(minutes: 8),
      const Duration(minutes: 10),
    );
    expect(service.checkpoint(resource)!['position'], 120000);
    expect(service.continueWatching(), hasLength(1));
    service.saveProgress(
      resource,
      current,
      const Duration(minutes: 10),
      const Duration(minutes: 10),
      completed: true,
    );
    expect(service.continueWatching(), isEmpty);
  });
  test('manual and other binding evidence survive binding removal', () async {
    final one = service.addFileSource('s');
    final two = service.addFileSource('s');
    await service.scan(one, sources);
    await service.scan(two, sources);
    final media = service.query().single['id'] as String;
    service.removeFileSource(one);
    expect(service.query(), hasLength(1));
    service.addManual(media);
    service.removeFileSource(two);
    expect(service.query(), hasLength(1));
    expect(service.resources(media), hasLength(1));
  });
  test('persisted page cursor resumes after restart without re-reading completed pages', () async {
    final binding = service.addFileSource('s');
    sources.handler = (request) async {
      if (request.offset == 0) {
        return BrowseResult(sources.entries, nextOffset: 100);
      }
      throw const PluginException('offline', 'offline');
    };
    await expectLater(
      service.scan(binding, sources),
      throwsA(isA<PluginException>()),
    );
    expect(service.query(), hasLength(1));
    // Reopening the repository reconstructs task state entirely from SQLite.
    service = LibraryService(service.db, configuration: service.configuration);
    sources.handler = (request) async {
      expect(request.offset, 100);
      return const BrowseResult([]);
    };
    await service.scan(binding, sources);
    expect(service.db.select('SELECT * FROM scan_tasks'), isEmpty);
    expect(
      service.db.select('SELECT available FROM evidence').single['available'],
      1,
    );
  });
  test('server stable content identity groups versions and retains series hierarchy', () async {
    const series = SourceMediaInfo(id: 'show', title: 'Series', kind: 'series');
    const season = SourceMediaInfo(
      id: 'season',
      title: 'Season 1',
      kind: 'season',
      parentId: 'show',
    );
    const episode = SourceMediaInfo(
      id: 'episode',
      title: 'Episode 1',
      kind: 'episode',
      parentId: 'season',
      season: 1,
      episode: 1,
    );
    final binding = service.addFileSource('s');
    // Use a server instance to retain its content semantics, without filename guessing.
    sources.handler = (request) async {
      if (request.node == null) {
        return const BrowseResult([
          SourceEntry(
            ResourceRef('s', 'show'),
            'Series',
            isFolder: true,
            media: series,
          ),
        ]);
      }
      if (request.node!.id == 'show') {
        return const BrowseResult([
          SourceEntry(
            ResourceRef('s', 'season'),
            'Season',
            isFolder: true,
            media: season,
          ),
        ]);
      }
      return const BrowseResult([
        SourceEntry(
          ResourceRef('s', 'one.mp4'),
          '1080p.mp4',
          isFolder: false,
          media: episode,
        ),
        SourceEntry(
          ResourceRef('s', 'two.mp4'),
          '4k.mp4',
          isFolder: false,
          media: episode,
        ),
      ]);
    };
    await service.scan(binding, sources);
    final show = service.query().single;
    expect(show['title'], 'Series');
    final seasonRow = service.children(show['id'] as String).single;
    final ep = service.children(seasonRow['id'] as String).single;
    expect(service.resources(ep['id'] as String), hasLength(2));
    expect(service.query(search: 'Episode'), hasLength(1));
    service.removeFileSource(binding);
    expect(service.query(), isEmpty);
  });
  test('same titles stay distinct and filters execute against authoritative records', () async {
    sources.entries = const [
      SourceEntry(
        ResourceRef('s', '/one.mp4'),
        'Same title.mp4',
        isFolder: false,
        media: SourceMediaInfo(
          id: 'one',
          title: 'Same title.mp4',
          kind: 'movie',
          year: 2020,
        ),
      ),
      SourceEntry(
        ResourceRef('s', '/two.mp4'),
        'Same title.mp4',
        isFolder: false,
      ),
    ];
    await service.scan(service.addFileSource('s'), sources);
    expect(service.query(), hasLength(2));
    expect(service.query(contentType: 'movie', year: 2020), hasLength(1));
    expect(service.query(contentType: 'video'), hasLength(1));
    expect(service.query(source: 'other'), isEmpty);
    final movie = service.query(contentType: 'movie').single['id'] as String;
    final resource = service.resources(movie).single['id'] as String;
    service.saveProgress(
      resource,
      service.beginSession(resource),
      const Duration(minutes: 10),
      const Duration(minutes: 10),
      completed: true,
    );
    expect(service.query(watched: true), hasLength(1));
    expect(service.query(watched: false), hasLength(1));
  });
  test('cyclic upstream hierarchy rolls back invalid media', () {
    service.register(
      const SourceEntry(
        ResourceRef('s', 'one'),
        'One',
        isFolder: true,
        media: SourceMediaInfo(
          id: 'one',
          title: 'One',
          kind: 'series',
          parentId: 'two',
        ),
      ),
    );
    expect(
      () => service.register(
        const SourceEntry(
          ResourceRef('s', 'two'),
          'Two',
          isFolder: true,
          media: SourceMediaInfo(
            id: 'two',
            title: 'Two',
            kind: 'season',
            parentId: 'one',
          ),
        ),
      ),
      throwsA(isA<PluginException>()),
    );
    expect(service.db.select('SELECT * FROM media'), hasLength(1));
  });
  test('a running scan reports the valid media files found so far', () async {
    final binding = service.addFileSource('s');
    final seen = <int>[];
    sources.handler = (request) async {
      if (request.node == null) {
        return const BrowseResult([
          SourceEntry(ResourceRef('s', 'dir'), 'dir', isFolder: true),
          SourceEntry(ResourceRef('s', 'a.mp4'), 'a.mp4', isFolder: false),
          SourceEntry(ResourceRef('s', 'b.mp4'), 'b.mp4', isFolder: false),
        ]);
      }
      // Asked while the second directory is being read.
      seen.add(service.scannedMediaCount(binding));
      return const BrowseResult([
        SourceEntry(ResourceRef('s', 'dir/c.mp4'), 'c.mp4', isFolder: false),
      ]);
    };
    await service.scan(binding, sources);
    expect(seen, [2]);
    expect(service.scannedMediaCount(binding), 0, reason: 'scan finished');
  });
  test('media that are only hidden dot files never show in the library', () {
    final sidecar = service.register(
      const SourceEntry(
        ResourceRef('s', '/._Film.mp4'),
        '._Film.mp4',
        isFolder: false,
      ),
    );
    final film = service.register(
      const SourceEntry(
        ResourceRef('s', '/Film.mp4'),
        'Film.mp4',
        isFolder: false,
      ),
    );
    service.addManual(sidecar);
    service.addManual(film);
    expect(service.query().map((m) => m['id']), [film]);
  });

  test(
    'episode lists and versions skip hidden dot files kept from old scans',
    () {
      const series = SourceMediaInfo(
        id: 'show',
        title: 'Series',
        kind: 'series',
      );
      const season = SourceMediaInfo(
        id: 'season',
        title: 'Season 1',
        kind: 'season',
        parentId: 'show',
      );
      SourceMediaInfo episode(String id) => SourceMediaInfo(
        id: id,
        title: 'Pilot',
        kind: 'episode',
        parentId: 'season',
        season: 1,
        episode: 1,
      );
      final show = service.register(
        const SourceEntry(
          ResourceRef('s', 'show'),
          'Series',
          isFolder: true,
          media: series,
        ),
      );
      service.register(
        const SourceEntry(
          ResourceRef('s', 'season'),
          'Season',
          isFolder: true,
          media: season,
        ),
      );
      // A macOS sidecar registered as its own episode (the duplicate row bug).
      service.register(
        SourceEntry(
          const ResourceRef('s', '/._S01E01.mkv'),
          '._S01E01.mkv',
          isFolder: false,
          media: episode('sidecar'),
        ),
      );
      final real = service.register(
        SourceEntry(
          const ResourceRef('s', '/S01E01.mkv'),
          'S01E01.mkv',
          isFolder: false,
          media: episode('real'),
        ),
      );
      // A sidecar attached to the real episode is not offered as a version.
      service.register(
        SourceEntry(
          const ResourceRef('s', '/._S01E01.v2.mkv'),
          '._S01E01.v2.mkv',
          isFolder: false,
          media: episode('real'),
        ),
      );
      final seasonRow = service.children(show).single;
      final episodes = service.children(seasonRow['id'] as String);
      expect(episodes.map((e) => e['id']), [real]);
      expect(service.resources(real).map((r) => r['name']), ['S01E01.mkv']);
    },
  );

  test(
    'a metadata series built only from hidden sidecars is not a duplicate',
    () {
      String episodeFile(String name) {
        final media = service.register(
          SourceEntry(ResourceRef('s', '/show/$name'), name, isFolder: false),
        );
        service.addManual(media);
        return media;
      }

      final real = episodeFile('Show.S01E01.mkv');
      final sidecar = episodeFile('._Show.S01E01.mkv');
      const show = MetadataRecord(
        ref: MetadataRef('tmdb', MediaKind.series, '1418'),
        fields: {'kind': 'series', 'title': 'Show'},
      );
      const season = MetadataRecord(
        ref: MetadataRef('tmdb', MediaKind.season, '3738'),
        fields: {'kind': 'season', 'title': 'Season 1'},
      );
      // Old builds grouped the sidecar into its own "local" containers.
      for (final (media, scope) in [(real, 's'), (sidecar, 'local')]) {
        service.metadata.attachHierarchy(media, [
          (scope: 'tmdb:$scope:series', record: show),
          (scope: 'tmdb:$scope:season', record: season),
        ], operationId: 'test-$scope');
      }
      final series = service.query(contentType: 'series');
      expect(series.map((m) => m['title']), ['Show']);
      final seasons = service.children(series.single['id'] as String);
      expect(seasons, hasLength(1));
      expect(
        service.children(seasons.single['id'] as String).map((m) => m['id']),
        [real],
      );
    },
  );

  test('background identification skips media that are only sidecars', () {
    final sidecar = service.register(
      const SourceEntry(
        ResourceRef('s', '/._Film.mp4'),
        '._Film.mp4',
        isFolder: false,
      ),
    );
    service.addManual(sidecar);
    final queue = MetadataQueue(service.db);
    while (true) {
      final work = queue.claim('test');
      if (work == null) break;
      expect(work['media_id'], isNot(sidecar));
      queue.finish(work['media_id'] as String, 'test', 'completed');
    }
    expect(queue.item(sidecar)!['state'], 'skipped');
  });
}
