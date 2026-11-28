import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/core/capabilities/metadata_capability.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/sources/file_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/capabilities/metadata/providers/nfo_metadata_plugin.dart';
import 'package:openplayx/capabilities/metadata/providers/tmdb_metadata_plugin.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/metadata/media_name_parser.dart';
import 'package:openplayx/capabilities/metadata/metadata_service.dart';

import '../support/library_test_helpers.dart';

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
  test('collection names: index before the year, owner before the title', () {
    final indexed = parser.parse(
      '01.1981.Taps.1920x1040.BDRip.x264.DTS-HD.MA.mkv',
    );
    expect((indexed.title, indexed.year), ('Taps', 1981));
    // A numeric title with nothing after the year stays the title.
    expect(parser.parse('300.2006.1080p.BluRay.mkv').title, '300');
    expect(parser.parse('1917.2019.1080p.BluRay.mkv').title, '1917');
    const owner = 'Jet Li [1992] - Swordsman II.avi';
    final collected = parser.parse(
      owner,
      path: '/m/Jet Li Movie Collection 1982-2008/$owner',
    );
    expect((collected.title, collected.year), ('Swordsman II', 1992));
    // Outside an owner's collection, "Title [Year] - Group" keeps the title.
    const release = 'Inception [2010] - YTS.mkv';
    expect(
      parser.parse(release, path: '/m/Inception [2010] - YTS/$release').title,
      'Inception',
    );
    expect(parser.parse('Sex.is.Zero.CD1.avi').title, 'Sex is Zero');
    expect(
      parser
          .parse('Harry.Potter.and.the.Deathly.Hallows.Part.2.2011.mkv')
          .title,
      'Harry Potter and the Deathly Hallows Part 2',
    );
  });
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
  test('series episodes named in words or only by folder are recognized', () {
    final spelled = parser.parse(
      'Desperate Housewives Season 6 Episode 21 - A Little Night Music.avi',
    );
    expect(
      (spelled.title, spelled.season, spelled.kind),
      ('Desperate Housewives', 6, MediaKind.episode),
    );
    expect(spelled.episodes, [21]);
    // A year in the episode's own title is not the series' year.
    final modern = parser.parse(
      'Modern Family S01E22 Airport 2010  (1080p x265 10bit Joy).mkv',
    );
    expect((modern.title, modern.year), ('Modern Family', null));
    final country = parser.parse(
      'Shameless (US) (2011) - S04E12 - Lazarus (1080p BluRay x265 afm72).mkv',
    );
    expect((country.title, country.year), ('Shameless', 2011));
    const bare = '/tv/The Wire (2002) Season 1-5/Season 3/S03E04.mkv';
    final wire = parser.parse('S03E04.mkv', path: bare);
    expect(
      (wire.title, wire.year, wire.season, wire.extra),
      ('The Wire', 2002, 3, false),
    );
    expect(wire.episodes, [4]);
  });
  test('bonus clips are marked and named after their series', () {
    final named = parser.parse(
      'Breaking Bad - S01 Extra - Screen Tests.mkv',
      path: '/movie/Breaking Bad - Complete Season 1,2,3,4,5 + Extras - BluRay 1080p/Extras/Breaking Bad - S01 Extra - Screen Tests.mkv',
    );
    expect((named.extra, named.title, named.season), (true, 'Breaking Bad', 1));
    expect(parser.parse('Show - S05Extra - Table Read.mkv').extra, isTrue);
    final folder = parser.parse(
      'Friends of Friends_new.mkv',
      path: '/movie/Friends (1994) Season 1-10 S01-S10 (1080p BluRay x265)/Featurettes/Season 7/Friends of Friends_new.mkv',
    );
    expect(
      (folder.extra, folder.title, folder.year, folder.season),
      (true, 'Friends', 1994, 7),
    );
    final deleted = parser.parse(
      'S08E06.mkv',
      path: '/movie/Shameless (US) (2011) Season 1-11/Featurettes/Season 8/Deleted Scenes/S08E06.mkv',
    );
    expect((deleted.extra, deleted.title), (true, 'Shameless'));
    expect(deleted.episodes, isEmpty);
    expect(
      parser.parse('Kung.fu.2004.BluRay.720p.x264.DTS-WiKi.Sample.mkv').extra,
      isTrue,
    );
    expect(parser.parse('Interstellar.2014.2160p.BluRay.mkv').extra, isFalse);
    expect(
      MediaNameParser.hostFolder(
        '/movie/Show (2011)/Featurettes/Season 8/Deleted Scenes/a.mkv',
      ),
      '/movie/Show (2011)',
    );
  });
  test('resolutions are not years and leading years/tags are not title', () {
    final bond = parser.parse(
      '1997.Tomorrow.Never.Dies.1920x820.BDRip.x264.DTS-HD.MA.mkv',
    );
    expect(bond.title, 'Tomorrow Never Dies');
    expect(bond.year, 1997);
    expect(bond.tags, contains('1920x820'));
    final hp = parser.parse(
      'Harry.Potter.And.The.Chamber.Of.Secrets.2002.1920x802.BDRip.mkv',
    );
    expect(
      (hp.title, hp.year),
      ('Harry Potter And The Chamber Of Secrets', 2002),
    );
    final anime = parser.parse(
      "[AnimeRG] Kiki's Delivery Service (1989) Witch's Delivery Service [1080p].mkv",
    );
    expect((anime.title, anime.year), ("Kiki's Delivery Service", 1989));
    final site = parser.parse('[www.example.com]Some.Film.2004.720p.mkv');
    expect((site.title, site.year), ('Some Film', 2004));
    // Numeric titles keep their number when nothing else follows or a later
    // year is the release year.
    expect(parser.parse('1917.mkv').title, '1917');
    expect(parser.parse('1917.1080p.mkv').year, isNull);
    final numeric = parser.parse('1917.2019.1080p.mkv');
    expect((numeric.title, numeric.year), ('1917', 2019));
    expect(parser.parse('[Group].mkv').title, 'Group');
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
      addToLibrary(library, media);
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
        addToLibrary(library, episode);
        await service.importSidecars(episode);
        final shows = library.query(contentType: 'series');
        expect(shows, hasLength(1));
        final seasons = library.children(shows.single['id'] as String);
        expect(seasons, hasLength(1));
        final episodes = library.children(seasons.single['id'] as String);
        expect(episodes.single['id'], episode);
        expect(episodes.single['title'], 'Second episode');
        expect(library.query(year: 2020).single['id'], episode);
        expect(library.db.select('SELECT * FROM resources'), hasLength(2));
        await service.importSidecars(episode);
        expect(library.query(contentType: 'series'), hasLength(1));
      },
    );
    test('TMDB alternative titles are read per kind and cached', () async {
      final paths = <String>[];
      final plugin = TmdbMetadataPlugin((path, query) async {
        paths.add(path);
        if (path == '/movie/911430/alternative_titles') {
          return {
            'id': 911430,
            'titles': [
              {'iso_3166_1': 'US', 'title': 'F1 The Movie', 'type': ''},
              {'iso_3166_1': 'GB', 'title': 'F1 The Movie', 'type': ''},
              {'iso_3166_1': 'CN', 'title': ' ', 'type': ''},
            ],
          };
        }
        return {
          'id': 10,
          'results': [
            {'iso_3166_1': 'JP', 'title': 'Show JP', 'type': ''},
          ],
        };
      });
      Future<List<String>> titles(MediaKind kind, String id) async =>
          ((await plugin.lookup(
                    MetadataRequest(
                      action: MetadataAction.alternativeTitles,
                      kind: kind,
                      ref: MetadataRef('tmdb', kind, id),
                    ),
                    CallContext.forInstance('tmdb'),
                  )).records.single.fields['alternativeTitles']
                  as List)
              .cast<String>();
      expect(await titles(MediaKind.movie, '911430'), ['F1 The Movie']);
      expect(await titles(MediaKind.movie, '911430'), ['F1 The Movie']);
      expect(await titles(MediaKind.series, '10'), ['Show JP']);
      expect(paths, [
        '/movie/911430/alternative_titles',
        '/tv/10/alternative_titles',
      ]);
      expect(
        () => MetadataRequest(
          action: MetadataAction.alternativeTitles,
          kind: MediaKind.season,
          ref: const MetadataRef('tmdb', MediaKind.season, '1'),
        ),
        throwsA(isA<PluginException>()),
      );
    });
    test('TMDB season IDs and parent show IDs stay separate', () async {
      final paths = <String>[];
      final plugin = TmdbMetadataPlugin((path, query) async {
        paths.add(path);
        if (path == '/configuration') {
          return {
            'images': {
              'secure_base_url': 'https://image.tmdb.org/t/p/',
              'still_sizes': ['w92', 'w185', 'w300', 'original'],
            },
          };
        }
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
          'still_path': '/episode.jpg',
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
      final episodeResult = await plugin.lookup(
        MetadataRequest(
          action: MetadataAction.details,
          kind: MediaKind.episode,
          ref: episodeRef,
        ),
        CallContext.forInstance('tmdb'),
      );
      expect(paths, contains('/tv/10/season/1/episode/2'));
      expect(
        episodeResult.records.single.artwork.single.remote!.path,
        '/t/p/w300/episode.jpg',
      );
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
          TmdbMetadataPlugin((path, query) async => {'results': <Object?>[]}),
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
    test(
      'clearing scraped metadata keeps files, progress and manual edits',
      () async {
        // A TMDB match on the movie, plus a user edit and playback progress.
        library.transaction(
          () => library.metadata.apply(
            media,
            MetadataRecord(
              ref: const MetadataRef('tmdb', MediaKind.movie, '1'),
              fields: const {'title': 'Scraped Film', 'overview': 'Plot'},
            ),
            sourceKey: 'tmdb',
            authority: 100,
            expectedRevision: 0,
            operationId: 'op',
            select: true,
          ),
        );
        library.metadata.overrideField(
          media,
          'year',
          1999,
          expectedRevision: library.metadata.revision(media),
        );
        final resource = library.resources(media).single['id'] as String;
        library.saveProgress(
          resource,
          library.beginSession(resource),
          const Duration(minutes: 5),
          const Duration(minutes: 90),
        );
        // A TV NFO import builds a series/season group around an episode.
        final show = await Directory('${root.path}/Show').create();
        final season = await Directory('${show.path}/Season 01').create();
        await File('${show.path}/tvshow.nfo').writeAsString(
          '<tvshow><title>Example Show</title><uniqueid type="tmdb">10</uniqueid></tvshow>',
        );
        final file = await File('${season.path}/Example.Show.S01E02.mkv')
            .writeAsString('video');
        await File('${season.path}/Example.Show.S01E02.nfo').writeAsString(
          '<episodedetails><title>Second episode</title><season>1</season><episode>2</episode></episodedetails>',
        );
        final episode = library.register(
          SourceEntry(
            ResourceRef('files', file.path),
            'Example.Show.S01E02.mkv',
            isFolder: false,
          ),
        );
        addToLibrary(library, episode);
        await service.importSidecars(episode);
        expect(library.query(contentType: 'series'), hasLength(1));
        final before = library.metadata.scrapedStats();
        expect(before.media, greaterThanOrEqualTo(2));
        expect(before.bytes, greaterThan(0));
        final resources = library.db.select('SELECT * FROM resources').length;

        library.metadata.clearScraped();

        expect(library.metadata.scrapedStats(), (media: 0, bytes: 0));
        // Scraped fields and the TMDB match are gone; the user edit stays.
        final fields = library.metadata.fields(media);
        expect(fields['title'], isNot('Scraped Film'));
        expect(fields['overview'], isNull);
        expect(fields['year'], 1999);
        expect(library.metadata.association(media), isNull);
        // The series group is removed; the episode is a plain item again.
        expect(library.query(contentType: 'series'), isEmpty);
        expect(library.query().map((m) => m['id']), contains(episode));
        expect(
          library.db.select("SELECT * FROM media WHERE id LIKE 'metadata:%'"),
          isEmpty,
        );
        // Files and playback progress are untouched.
        expect(
          library.db.select('SELECT * FROM resources'),
          hasLength(resources),
        );
        expect(library.db.select('SELECT * FROM progress'), hasLength(1));
        expect(library.db.select('PRAGMA foreign_key_check'), isEmpty);
        // Everything is queued for scraping again.
        expect(
          library.db.select(
            "SELECT * FROM metadata_queue WHERE state<>'queued'",
          ),
          isEmpty,
        );
      },
    );
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
