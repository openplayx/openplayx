import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/core/plugins/metadata_capability.dart';
import 'package:openplayx/data/metadata/metadata_queue.dart';

import '../support/library_test_helpers.dart';

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
      service.setFileSourceEnabled(a, true);
      service.renameFileSource(b, '  Shows ');
      expect(service.fileSources().last['name'], 'Shows');
      expect(() => service.renameFileSource(b, ' '), throwsArgumentError);
    },
  );
  test(
    'metadata series and seasons follow their episodes\' file sources',
    () async {
      final a = service.addFileSource('s', root: '/a');
      sources.entries = [
        const SourceEntry(
          ResourceRef('s', '/a/show.s01e01.mp4'),
          'Show.S01E01.mp4',
          isFolder: false,
        ),
      ];
      await service.scan(a, sources);
      final episode =
          service.db.select('SELECT id FROM media').single['id'] as String;
      // Scraping groups the episode under series and season containers that
      // have no files or evidence of their own.
      for (final id in ['metadata:series', 'metadata:season']) {
        service.db.execute('INSERT INTO media(id,title) VALUES (?,?)', [
          id,
          'Show',
        ]);
      }
      final now = DateTime.now().microsecondsSinceEpoch;
      service.db.execute('INSERT INTO memberships VALUES (?,?),(?,?)', [
        'metadata:series',
        now,
        'metadata:season',
        now,
      ]);
      service.db.execute('INSERT INTO metadata_relations VALUES (?,?),(?,?)', [
        'metadata:series',
        'metadata:season',
        'metadata:season',
        episode,
      ]);
      expect(service.query().map((r) => r['id']), ['metadata:series']);
      expect(service.children('metadata:series'), hasLength(1));

      service.setFileSourceEnabled(a, false);
      expect(service.query(), isEmpty);
      expect(service.children('metadata:series'), isEmpty);
      expect(service.children('metadata:season'), isEmpty);

      service.setFileSourceEnabled(a, true);
      expect(service.query().map((r) => r['id']), ['metadata:series']);

      // Deleting the file source deletes the episode, then the season and
      // series left without episodes.
      service.removeFileSource(a);
      expect(service.query(), isEmpty);
      expect(service.db.select('SELECT * FROM media'), isEmpty);
      expect(service.db.select('SELECT * FROM metadata_relations'), isEmpty);
      expect(service.db.select('SELECT * FROM memberships'), isEmpty);
    },
  );
  test('continue watching follows file sources like the poster wall', () async {
    final a = service.addFileSource('s', root: '/a');
    sources.entries = [
      const SourceEntry(
        ResourceRef('s', '/a/film.mp4'),
        'Film.mp4',
        isFolder: false,
      ),
    ];
    await service.scan(a, sources);
    final media = service.query().single['id'] as String;
    void watchHalf(String media) {
      final resource = service.resources(media).single['id'] as String;
      service.saveProgress(
        resource,
        service.beginSession(resource),
        const Duration(minutes: 5),
        const Duration(minutes: 10),
      );
    }

    watchHalf(media);
    // Played by browsing a source, never scanned: progress is kept but the
    // media is in no file source.
    final browsed = service.register(
      const SourceEntry(
        ResourceRef('s', '/elsewhere/clip.mp4'),
        'Clip.mp4',
        isFolder: false,
      ),
    );
    watchHalf(browsed);
    expect(service.continueWatching().map((r) => r['id']), [media]);

    service.setFileSourceEnabled(a, false);
    expect(service.continueWatching(), isEmpty);
    service.setFileSourceEnabled(a, true);
    expect(service.continueWatching().map((r) => r['id']), [media]);

    service.removeFileSource(a);
    expect(service.continueWatching(), isEmpty);
  });
  test(
    'a series split across file sources keeps only enabled episodes',
    () async {
      final a = service.addFileSource('s', root: '/a');
      final b = service.addFileSource('s', root: '/b');
      Future<String> scanEpisode(String fileSource, String path) async {
        sources.entries = [
          SourceEntry(ResourceRef('s', path), path, isFolder: false),
        ];
        await service.scan(fileSource, sources);
        return service.db.select(
              'SELECT r.media_id FROM resources r '
              'JOIN resource_locators l ON l.resource_id=r.id WHERE l.item=?',
              [path],
            ).single['media_id']
            as String;
      }

      final e1 = await scanEpisode(a, '/a/show.s01e01.mp4');
      final e2 = await scanEpisode(b, '/b/show.s01e02.mp4');
      for (final id in ['metadata:series', 'metadata:season']) {
        service.db.execute('INSERT INTO media(id,title) VALUES (?,?)', [
          id,
          'Show',
        ]);
        service.db.execute('INSERT INTO memberships VALUES (?,?)', [id, 1]);
      }
      service.db.execute(
        'INSERT INTO metadata_relations VALUES (?,?),(?,?),(?,?)',
        [
          'metadata:series',
          'metadata:season',
          'metadata:season',
          e1,
          'metadata:season',
          e2,
        ],
      );
      List<Object?> episodes() =>
          service.children('metadata:season').map((r) => r['id']).toList();
      expect(service.query().map((r) => r['id']), ['metadata:series']);
      expect(episodes(), unorderedEquals([e1, e2]));

      service.setFileSourceEnabled(a, false);
      expect(service.query().map((r) => r['id']), ['metadata:series']);
      expect(episodes(), [e2]);

      // Deleting B deletes its episode; the series keeps A's (disabled)
      // episode and stays hidden until A is enabled again.
      service.removeFileSource(b);
      expect(service.query(), isEmpty);
      expect(episodes(), isEmpty);
      expect(
        service.db.select('SELECT 1 FROM media WHERE id=?', [e2]),
        isEmpty,
      );
      service.setFileSourceEnabled(a, true);
      expect(service.query().map((r) => r['id']), ['metadata:series']);
      expect(episodes(), [e1]);
    },
  );
  test(
    'disabled connections hide their file sources; deleted ones remove them',
    () async {
      final a = service.addFileSource('s', root: '/a');
      sources.entries = [
        const SourceEntry(
          ResourceRef('s', '/a/film.mp4'),
          'Film.mp4',
          isFolder: false,
        ),
      ];
      await service.scan(a, sources);
      final media = service.query().single['id'] as String;
      final resource = service.resources(media).single['id'] as String;
      service.saveProgress(
        resource,
        service.beginSession(resource),
        const Duration(minutes: 5),
        const Duration(minutes: 10),
      );
      // The connection `s` as the source page saves it, disabled.
      service.repository.configuration.execute(
        'INSERT INTO plugin_instance_configs VALUES (?,?,?,?,?,?,?)',
        ['s', 'source.local', '{}', 1, 1, 0, null],
      );
      expect(service.query(), isEmpty);
      expect(service.continueWatching(), isEmpty);
      service.repository.configuration.execute(
        'UPDATE plugin_instance_configs SET enabled_desired=1',
      );
      expect(service.query().single['id'], media);
      expect(service.continueWatching().single['id'], media);

      expect(service.fileSourcesOf('s'), [a]);
      service.removeFileSourcesOf('s');
      expect(service.fileSources(), isEmpty);
      expect(service.db.select('SELECT * FROM media'), isEmpty);
    },
  );
  group('versions', () {
    /// Scans [files] (path → size) into one file source and identifies each
    /// as the TMDB title [ids] maps it to.
    Future<Map<String, String>> scanIdentified(
      Map<String, int?> files,
      Map<String, String> ids, {
      String kind = 'movie',
    }) async {
      final fileSource = service.addFileSource('s');
      sources.entries = [
        for (final e in files.entries)
          SourceEntry(
            ResourceRef('s', e.key),
            e.key.substring(1),
            isFolder: false,
            size: e.value,
          ),
      ];
      await service.scan(fileSource, sources);
      final media = {
        for (final path in files.keys)
          path:
              service.db.select('SELECT media_id FROM resources WHERE item=?', [
                    path,
                  ]).single['media_id']
                  as String,
      };
      for (final e in ids.entries) {
        service.db.execute(
          'INSERT OR REPLACE INTO metadata_state(media_id,fallback_title,association) VALUES (?,?,?)',
          [
            media[e.key],
            e.key,
            '{"provider":"tmdb","kind":"$kind","id":"${e.value}"}',
          ],
        );
      }
      return media;
    }

    test('files identified as one movie show once, largest first', () async {
      final media = await scanIdentified(
        {'/small.mkv': 1 << 30, '/large.mkv': 4 << 30, '/unknown.mkv': null},
        {'/small.mkv': '1', '/large.mkv': '1', '/unknown.mkv': '1'},
      );
      final rows = service.query();
      expect(rows, hasLength(1));
      expect(rows.single['total'], 1);
      final card = rows.single['id'] as String;
      expect(service.versions(card).map((r) => r['name']), [
        'large.mkv',
        'small.mkv',
        'unknown.mkv',
      ]);
      expect(service.versions(card).first['size'], 4 << 30);

      // Favorites and hiding cover every version.
      service.favorite(card, true);
      expect(service.db.select('SELECT favorite FROM media').map((r) => r[0]), [
        1,
        1,
        1,
      ]);
      service.hide(card);
      expect(service.query(), isEmpty);
      service.clearIgnored();

      // Correcting a match splits that file off again.
      service.db.execute(
        'UPDATE metadata_state SET association=? WHERE media_id=?',
        ['{"provider":"tmdb","kind":"movie","id":"2"}', media['/small.mkv']],
      );
      expect(service.versions(media['/small.mkv']!), hasLength(1));
      expect(service.versions(media['/large.mkv']!).map((r) => r['name']), [
        'large.mkv',
        'unknown.mkv',
      ]);
    });

    test('rescans record and update file sizes', () async {
      final media = await scanIdentified({'/film.mkv': 100}, {});
      expect(service.versions(media['/film.mkv']!).single['size'], 100);
      sources.entries = [
        const SourceEntry(
          ResourceRef('s', '/film.mkv'),
          'film.mkv',
          isFolder: false,
          size: 200,
        ),
      ];
      await service.scan(service.fileSources().single['id'] as String, sources);
      expect(service.versions(media['/film.mkv']!).single['size'], 200);
    });

    test('an episode with several files is listed once', () async {
      final media = await scanIdentified(
        {'/e1.mkv': 10, '/e1.hd.mkv': 20, '/e2.mkv': 10},
        {'/e1.mkv': '101', '/e1.hd.mkv': '101', '/e2.mkv': '102'},
        kind: 'episode',
      );
      service.db.execute('INSERT INTO media(id,title) VALUES (?,?)', [
        'metadata:season',
        'Season 1',
      ]);
      for (final episode in media.values) {
        service.db.execute('INSERT INTO metadata_relations VALUES (?,?)', [
          'metadata:season',
          episode,
        ]);
      }
      final episodes = service.children('metadata:season');
      expect(episodes, hasLength(2));
      expect(service.versions(media['/e1.mkv']!).map((r) => r['name']), [
        'e1.hd.mkv',
        'e1.mkv',
      ]);
    });

    test(
      'continue watching shows a title once, at the version played last',
      () async {
        final media = await scanIdentified(
          {'/a.mkv': 10, '/b.mkv': 20},
          {'/a.mkv': '1', '/b.mkv': '1'},
        );
        String watch(String path) {
          final resource =
              service.resources(media[path]!).single['id'] as String;
          service.saveProgress(
            resource,
            service.beginSession(resource),
            const Duration(minutes: 5),
            const Duration(minutes: 10),
          );
          return resource;
        }

        watch('/a.mkv');
        await Future<void>.delayed(const Duration(milliseconds: 2));
        final last = watch('/b.mkv');
        final rows = service.continueWatching();
        expect(rows, hasLength(1));
        expect(rows.single['resource_id'], last);
      },
    );

    test('versions from disabled file sources are left out', () async {
      final media = await scanIdentified({'/a.mkv': 10}, {'/a.mkv': '1'});
      final other = service.addFileSource('s', root: '/other');
      sources.entries = [
        const SourceEntry(
          ResourceRef('s', '/other/b.mkv'),
          'b.mkv',
          isFolder: false,
          size: 99,
        ),
      ];
      await service.scan(other, sources);
      final b =
          service.db
                  .select(
                    "SELECT media_id FROM resources WHERE item='/other/b.mkv'",
                  )
                  .single['media_id']
              as String;
      service.db.execute(
        'INSERT OR REPLACE INTO metadata_state(media_id,fallback_title,association) VALUES (?,?,?)',
        [b, 'b', '{"provider":"tmdb","kind":"movie","id":"1"}'],
      );
      expect(service.versions(media['/a.mkv']!), hasLength(2));
      service.setFileSourceEnabled(other, false);
      expect(service.versions(media['/a.mkv']!).map((r) => r['name']), [
        'a.mkv',
      ]);
    });
  });
  test('hide removes a title from every library and can be restored', () {
    final media = service.register(sources.entries.first);
    addToLibrary(service, media);
    addToLibrary(service, media);
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
      addToLibrary(service, shared);
      addToLibrary(service, shared);
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

  test('completed media leave continue watching', () {
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
  });
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
    'hiding persists across scans and removing the file source deletes it',
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
      expect(service.resources(media), isEmpty);
      expect(service.db.select('SELECT * FROM media'), isEmpty);
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
    addToLibrary(service, media);
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
  test(
    'other file sources keep shared media until the last one is removed',
    () async {
      final one = service.addFileSource('s');
      final two = service.addFileSource('s');
      await service.scan(one, sources);
      await service.scan(two, sources);
      final media = service.query().single['id'] as String;
      final resource = service.resources(media).single['id'] as String;
      service.saveProgress(
        resource,
        service.beginSession(resource),
        const Duration(minutes: 5),
        const Duration(minutes: 10),
      );
      service.removeFileSource(one);
      expect(service.query().single['id'], media);
      expect(service.checkpoint(resource), isNotNull);
      // The last file source takes the file record, progress and media along.
      service.removeFileSource(two);
      expect(service.query(), isEmpty);
      expect(service.checkpoint(resource), isNull);
      for (final table in [
        'media',
        'resources',
        'resource_locators',
        'progress',
        'evidence',
        'media_evidence',
        'memberships',
        'metadata_queue',
      ]) {
        expect(
          service.db.select('SELECT * FROM $table'),
          isEmpty,
          reason: table,
        );
      }
    },
  );
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
  test('media that are only hidden dot files never show anywhere', () {
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
    addToLibrary(service, sidecar);
    addToLibrary(service, film);
    expect(service.query().map((m) => m['id']), [film]);
    // Even with progress, as kept from an old scan.
    for (final media in [sidecar, film]) {
      final resource =
          service.db.select('SELECT id FROM resources WHERE media_id=?', [
                media,
              ]).single['id']
              as String;
      service.saveProgress(
        resource,
        service.beginSession(resource),
        const Duration(minutes: 1),
        const Duration(minutes: 10),
      );
    }
    expect(service.continueWatching().map((m) => m['id']), [film]);
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
      final sidecar = service.register(
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
      // Both came from a scan of an enabled file source.
      addToLibrary(service, sidecar);
      addToLibrary(service, real);
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
        addToLibrary(service, media);
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
    addToLibrary(service, sidecar);
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
