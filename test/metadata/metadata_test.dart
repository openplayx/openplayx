import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/core/plugins/metadata_capability.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/file_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/plugins/metadata_nfo/nfo_metadata_plugin.dart';
import 'package:openplayx/plugins/metadata_tmdb/tmdb_metadata_plugin.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/services/metadata/media_name_parser.dart';
import 'package:openplayx/services/metadata/metadata_service.dart';

class FixtureSources extends SourceManager {
  FixtureSources(this.root);
  final Directory root;
  int revision = 0;
  @override
  List<SourceConfig> get configs => [
    SourceConfig(
      id: 'files',
      kind: SourceKind.local,
      name: 'Files',
      address: root.path,
      revision: revision,
    ),
  ];
  @override
  Future<void> load() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) =>
      LocalFolderPlugin(configs.single)
          .browse(request, CallContext.forInstance(id));
  @override
  Future<List<int>> readAttachment(
    ResourceRef ref, {
    int maxBytes = 1024 * 1024,
  }) => LocalFolderPlugin(configs.single).readAttachment(
    ref,
    CallContext.forInstance(ref.instanceId),
    maxBytes: maxBytes,
  );
}

void main() {
  const parser = MediaNameParser();
  test('filename parsing preserves explicit episode and resource evidence', () {
    final movie = parser.parse('Interstellar.2014.2160p.BluRay.mkv');
    expect(movie.title, 'Interstellar');
    expect(movie.year, 2014);
    expect(movie.tags, ['2160p', 'BluRay']);
    final episode = parser.parse('Example.Show.S02E03E04.1080p.mkv');
    expect(episode.title, 'Example Show');
    expect(episode.season, 2);
    expect(episode.episodes, [3, 4]);
    expect(episode.kind, MediaKind.episode);
    expect(parser.parse('1917.mkv').year, isNull);
    expect(parser.parse('Film.1080p.mkv').year, isNull);
    expect(parser.parse('三体 第2季第3集.mkv').episodes, [3]);
  });
  test('NFO parses supported data, typed IDs, provenance and diagnostics', () {
    final plugin = NfoMetadataPlugin(
      (ref, {int maxBytes = 1024 * 1024}) async => [],
    );
    final record = plugin.parse(
      utf8.encode(
        '''<movie><title>影片 &amp; 标题</title>
      <year>2014</year><plot>简介</plot><genre>科幻</genre>
      <uniqueid type="tmdb">157336</uniqueid><thumb>poster.jpg</thumb>
      <fanart><thumb>../private.jpg</thumb></fanart><playcount>99</playcount>
      <ratings><rating name="imdb" max="10"><value>8.7</value></rating></ratings></movie>''',
      ),
      const ResourceRef('files', '/films/film.nfo'),
    );
    expect(record.title, '影片 & 标题');
    expect(record.externalIds.single.provider, 'tmdb');
    expect(record.fields['ratings']['imdb']['value'], 8.7);
    expect(record.artwork.single.source!.id, '/films/poster.jpg');
    expect(record.fields.containsKey('playcount'), isFalse);
    expect(record.warnings, contains('unsupported:playcount'));
    expect(record.contentRevision, hasLength(64));
  });
  test('NFO rejects entities, oversized inputs and deep trees', () {
    final plugin = NfoMetadataPlugin(
      (ref, {int maxBytes = 1024 * 1024}) async => [],
    );
    for (final xml in [
      '<!DOCTYPE movie [<!ENTITY x SYSTEM "file:///etc/passwd">]><movie><title>&x;</title></movie>',
      '<movie>${List.filled(35, '<a>').join()}${List.filled(35, '</a>').join()}</movie>',
    ]) {
      expect(
        () => plugin.parse(utf8.encode(xml), const ResourceRef('s', '/m.nfo')),
        throwsA(isA<PluginException>()),
      );
    }
    expect(
      relativeAttachment(
        const ResourceRef('s', '/m.nfo'),
        'https://example.com/x.jpg',
      ),
      isNull,
    );
    expect(
      relativeAttachment(const ResourceRef('s', '/m.nfo'), '/etc/a.jpg'),
      isNull,
    );
    expect(
      relativeAttachment(const ResourceRef('s', '/m.nfo'), '../x.jpg'),
      isNull,
    );
  });

  group('host metadata', () {
    late LibraryService library;
    late FixtureSources sources;
    late Directory root;
    late MetadataService service;
    late String media;
    late File video;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('openplayx-metadata-');
      sources = FixtureSources(root);
      library = LibraryService(sqlite3.openInMemory());
      video = await File('${root.path}/Film.2014.mkv').writeAsString('video');
      media = library.register(
        SourceEntry(
          ResourceRef('files', video.path),
          'Film.2014.mkv',
          isFolder: false,
        ),
      );
      library.addManual(library.create('Films', type: 'movie'), media);
      service = MetadataService(library, sources);
    });
    tearDown(() async {
      await service.dispose();
      library.close();
      await root.delete(recursive: true);
    });
    Future<void> nfo(
      String title, {
      String id = '1',
      String filename = 'Film.2014.nfo',
    }) => File('${root.path}/$filename').writeAsString(
      '<movie><title>$title</title><year>2014</year><uniqueid type="tmdb">$id</uniqueid></movie>',
    );
    test(
      'TV NFO imports only owned episode hierarchy and filters by metadata',
      () async {
        final show = await Directory('${root.path}/Show').create();
        final season = await Directory('${show.path}/Season 01').create();
        await File('${show.path}/tvshow.nfo').writeAsString(
          '<tvshow><title>Example Show</title><uniqueid type="tmdb">10</uniqueid></tvshow>',
        );
        final file = await File('${season.path}/Example.Show.S01E02.mkv')
            .writeAsString('video');
        await File('${season.path}/Example.Show.S01E02.nfo').writeAsString(
          '<episodedetails><title>Second episode</title><season>1</season><episode>2</episode><year>2020</year></episodedetails>',
        );
        final episode = library.register(
          SourceEntry(
            ResourceRef('files', file.path),
            'Example.Show.S01E02.mkv',
            isFolder: false,
          ),
        );
        final lib = library.libraries.single['id'] as String;
        library.addManual(lib, episode);
        await service.importSidecars(episode);
        final shows = library.query(lib, contentType: 'series');
        expect(shows, hasLength(1));
        final seasons = library.children(
          shows.single['id'] as String,
          library: lib,
        );
        expect(seasons, hasLength(1));
        final episodes = library.children(
          seasons.single['id'] as String,
          library: lib,
        );
        expect(episodes.single['id'], episode);
        expect(episodes.single['title'], 'Second episode');
        expect(library.query(lib, year: 2020).single['id'], episode);
        expect(library.db.select('SELECT * FROM resources'), hasLength(2));
        await service.importSidecars(episode);
        expect(library.query(lib, contentType: 'series'), hasLength(1));
      },
    );
    test('TMDB season IDs and parent show IDs stay separate', () async {
      final paths = <String>[];
      final plugin = TmdbMetadataPlugin((path, query) async {
        paths.add(path);
        if (path == '/configuration') return {'images': {}};
        if (path == '/tv/10') {
          return {
            'id': 10,
            'name': 'Show',
            'seasons': [
              {'id': 20, 'name': 'Season 1', 'season_number': 1},
            ],
          };
        }
        if (path == '/tv/10/season/1') {
          return {
            'id': 20,
            'name': 'Season 1',
            'season_number': 1,
            'episodes': [
              {
                'id': 30,
                'name': 'Episode 2',
                'season_number': 1,
                'episode_number': 2,
              },
            ],
          };
        }
        return {
          'id': 30,
          'name': 'Episode 2',
          'season_number': 1,
          'episode_number': 2,
        };
      });
      final show = (await plugin.lookup(
        MetadataRequest(
          action: MetadataAction.details,
          kind: MediaKind.series,
          ref: const MetadataRef('tmdb', MediaKind.series, '10'),
        ),
        CallContext.forInstance('tmdb'),
      )).records.single;
      final seasonRef = show.children.single.ref;
      expect(seasonRef.id, '20');
      expect(seasonRef.seriesId, '10');
      final season = (await plugin.lookup(
        MetadataRequest(
          action: MetadataAction.details,
          kind: MediaKind.season,
          ref: seasonRef,
        ),
        CallContext.forInstance('tmdb'),
      )).records.single;
      final episodeRef = season.children.single.ref;
      expect(episodeRef.id, '30');
      expect(episodeRef.seriesId, '10');
      await plugin.lookup(
        MetadataRequest(
          action: MetadataAction.details,
          kind: MediaKind.episode,
          ref: episodeRef,
        ),
        CallContext.forInstance('tmdb'),
      );
      expect(paths, contains('/tv/10/season/1/episode/2'));
    });
    test('artwork selection locks survive refreshed provider candidates and cache reset', () {
      const first = ArtworkDescriptor(
        id: 'first',
        type: 'poster',
        remote: null,
      );
      const second = ArtworkDescriptor(
        id: 'second',
        type: 'poster',
        remote: null,
      );
      MetadataRecord record(List<ArtworkDescriptor> art) => MetadataRecord(
        ref: const MetadataRef('tmdb', MediaKind.movie, '1'),
        fields: const {'title': 'Film'},
        artwork: art,
      );
      library.transaction(
        () => library.metadata.apply(
          media,
          record([first]),
          sourceKey: 'tmdb',
          authority: 100,
          expectedRevision: 0,
          operationId: 'initial',
          select: true,
        ),
      );
      library.transaction(
        () => library.metadata.selectArtwork(media, first, expectedRevision: 1),
      );
      library.transaction(
        () => library.metadata.apply(
          media,
          record([second]),
          sourceKey: 'tmdb',
          authority: 100,
          expectedRevision: 2,
          operationId: 'refresh-art',
        ),
      );
      expect(library.metadata.selectedArtwork(media)!.id, 'first');
      library.transaction(
        () => library.metadata.reset(
          media,
          expectedRevision: 3,
          operationId: 'reset-art',
        ),
      );
      expect(library.metadata.selectedArtwork(media)!.id, 'first');
      expect(library.resources(media), hasLength(1));
    });
    test('unlocking a vanished poster restores the current work candidate', () {
      const old = ArtworkDescriptor(id: 'old', type: 'poster');
      const current = ArtworkDescriptor(id: 'current', type: 'poster');
      MetadataRecord record(ArtworkDescriptor artwork) => MetadataRecord(
        ref: const MetadataRef('tmdb', MediaKind.movie, '1'),
        fields: const {'title': 'Film'},
        artwork: [artwork],
      );
      library.transaction(
        () => library.metadata.apply(
          media,
          record(old),
          sourceKey: 'tmdb',
          authority: 100,
          expectedRevision: 0,
          operationId: 'old',
          select: true,
        ),
      );
      library.transaction(
        () => library.metadata.selectArtwork(media, old, expectedRevision: 1),
      );
      library.transaction(
        () => library.metadata.apply(
          media,
          record(current),
          sourceKey: 'tmdb',
          authority: 100,
          expectedRevision: 2,
          operationId: 'new',
        ),
      );
      expect(library.metadata.selectedArtwork(media)!.id, 'old');
      library.transaction(
        () => library.metadata.unlockArtwork(media, expectedRevision: 3),
      );
      expect(library.metadata.selectedArtwork(media)!.id, 'current');
      expect(library.metadata.artworkLocked(media), isFalse);
    });
    test('identical NFO imports do not invalidate pending revisions', () async {
      await nfo('Film');
      await service.importSidecars(media);
      final revision = library.metadata.revision(media);
      await service.importSidecars(media);
      expect(library.metadata.revision(media), revision);
    });
    test(
      'one malformed sidecar does not discard other valid local metadata',
      () async {
        await nfo('Exact');
        await File('${root.path}/movie.nfo').writeAsString('<movie><broken>');
        await service.importSidecars(media);
        expect(library.metadata.fields(media)['title'], 'Exact');
      },
    );
    test('imports scoped NFO idempotently, locks fields and retains deleted metadata', () async {
      await nfo('Original');
      await service.importSidecars(media);
      expect(library.metadata.fields(media)['title'], 'Original');
      final revision = library.metadata.revision(media);
      library.rename(media, 'User title');
      await nfo('Updated');
      await service.importSidecars(media);
      expect(library.metadata.fields(media)['title'], 'User title');
      expect(library.metadata.revision(media), greaterThan(revision));
      expect(
        library.db.select('SELECT * FROM metadata_observations'),
        hasLength(1),
      );
      await File('${root.path}/Film.2014.nfo').delete();
      await service.importSidecars(media);
      expect(library.metadata.provenance(media)['year']['missing'], isTrue);
      library.transaction(
        () => library.metadata.overrideField(
          media,
          'title',
          null,
          expectedRevision: library.metadata.revision(media),
        ),
      );
      expect(library.metadata.fields(media)['title'], 'Updated');
    });
    test(
      'multi-video directory never spreads directory-level metadata or artwork',
      () async {
        await File('${root.path}/Other.mkv').writeAsString('video');
        await nfo('Wrong', filename: 'movie.nfo');
        await service.importSidecars(media);
        expect(library.metadata.association(media), isNull);
        await nfo('Exact');
        await service.importSidecars(media);
        expect(library.metadata.fields(media)['title'], 'Exact');
      },
    );
    test(
      'conflicting exact and generic IDs wait for explicit local confirmation',
      () async {
        await nfo('Exact', id: '1');
        await nfo('Generic', id: '2', filename: 'movie.nfo');
        await service.importSidecars(media);
        final job = library.metadata.latestJob(media)!;
        expect(job['stage'], 'awaitingSelection');
        expect(library.metadata.association(media), isNull);
        await service.chooseLocal(job['id'] as String, 0);
        expect(library.metadata.fields(media)['title'], 'Exact');
        expect(library.metadata.confirmed(media), isTrue);
      },
    );
    test(
      'TMDB search awaits selection; rematching leaves playback data intact',
      () async {
        service.registry.register(
          'tmdb',
          TmdbMetadataPlugin((path, query) async {
            if (path == '/configuration') {
              return {
                'images': {
                  'secure_base_url': 'https://image.tmdb.org/t/p/',
                  'poster_sizes': ['w500'],
                },
              };
            }
            if (path.startsWith('/search')) {
              return {
                'results': [
                  {'id': 1, 'title': 'Film', 'release_date': '2014-01-01'},
                ],
              };
            }
            return {
              'id': 1,
              'title': 'Film',
              'overview': 'Plot',
              'poster_path': '/a.jpg',
            };
          }),
        );
        final resource = library.resources(media).single['id'] as String;
        library.saveProgress(
          resource,
          library.beginSession(resource),
          const Duration(minutes: 5),
          const Duration(hours: 2),
        );
        final id = await service.search(media, query: 'Film', year: 2014);
        expect(library.metadata.association(media), isNull);
        expect(library.metadata.job(id)['stage'], 'awaitingSelection');
        await service.confirm(
          id,
          const MetadataRef('tmdb', MediaKind.movie, '1'),
        );
        expect(library.metadata.fields(media)['overview'], 'Plot');
        expect(library.checkpoint(resource)!['position'], 300000);
        expect(library.resources(media).single['id'], resource);
        expect(
          library.metadata.selectedArtwork(media)!.remote.toString(),
          'https://image.tmdb.org/t/p/w500/a.jpg',
        );
      },
    );
    test(
      'stale query after user editing cannot overwrite a new choice',
      () async {
        final pending = Completer<Map<String, dynamic>>();
        service.registry.register(
          'tmdb',
          TmdbMetadataPlugin((path, query) => pending.future),
        );
        final result = service.search(media, query: 'Film');
        library.rename(media, 'New title');
        pending.complete({
          'results': [
            {'id': 2, 'title': 'Old result'},
          ],
        });
        await expectLater(result, throwsA(isA<PluginException>()));
        expect(library.metadata.fields(media)['title'], 'New title');
        expect(library.metadata.latestJob(media)!['stage'], 'cancelled');
      },
    );
    test(
      'provider failure and no results are distinct and retain local data',
      () async {
        await nfo('Local');
        await service.importSidecars(media);
        service.registry.register(
          'tmdb',
          TmdbMetadataPlugin((path, query) async => {'results': []}),
        );
        final id = await service.search(media, query: 'Nothing');
        expect(library.metadata.job(id)['stage'], 'unmatched');
        expect(library.metadata.fields(media)['title'], 'Local');
        await expectLater(
          service.refresh(media),
          throwsA(isA<PluginException>()),
        );
        expect(library.metadata.latestJob(media)!['stage'], 'failed');
        expect(library.metadata.fields(media)['title'], 'Local');
      },
    );
    test('stale source configuration blocks sidecar commits', () async {
      await nfo('Local');
      // Reload mutates configuration after collection.
      final changing = ChangingSources(root);
      final changingService = MetadataService(library, changing);
      await expectLater(
        changingService.importSidecars(media),
        throwsA(isA<PluginException>()),
      );
      expect(library.metadata.association(media), isNull);
      await changingService.dispose();
    });
    test('atomic commit operation IDs are idempotent and stale revisions roll back', () {
      final record = MetadataRecord(
        ref: const MetadataRef('tmdb', MediaKind.movie, '1'),
        fields: const {'title': 'Film'},
      );
      void apply(int revision, String operation) => library.transaction(
        () => library.metadata.apply(
          media,
          record,
          sourceKey: 'tmdb',
          authority: 100,
          expectedRevision: revision,
          operationId: operation,
          select: true,
        ),
      );
      apply(0, 'one');
      apply(0, 'one');
      expect(library.metadata.revision(media), 1);
      expect(() => apply(0, 'two'), throwsA(isA<PluginException>()));
      expect(library.db.select('SELECT * FROM metadata_history'), hasLength(1));
    });
    test(
      'attachment reads reject owner substitution and symlink escapes',
      () async {
        final plugin = LocalFolderPlugin(sources.configs.single);
        await expectLater(
          plugin.readAttachment(
            ResourceRef('other', '${root.path}/x.nfo'),
            CallContext.forInstance('files'),
            maxBytes: 1024,
          ),
          throwsA(isA<PluginException>()),
        );
        final outside = await Directory.systemTemp.createTemp(
          'openplayx-outside-',
        );
        try {
          final secret = await File('${outside.path}/x.nfo')
              .writeAsString('private');
          final link = await Link('${root.path}/x.nfo').create(secret.path);
          await expectLater(
            plugin.readAttachment(
              ResourceRef('files', link.path),
              CallContext.forInstance('files'),
              maxBytes: 1024,
            ),
            throwsA(isA<PluginException>()),
          );
        } finally {
          await outside.delete(recursive: true);
        }
      },
    );
  });
}

class ChangingSources extends FixtureSources {
  ChangingSources(super.root);
  @override
  Future<void> reload() async {
    revision++;
  }
}
