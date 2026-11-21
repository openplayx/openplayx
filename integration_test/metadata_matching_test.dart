import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/app/debug_seed/debug_seed.dart';
import 'package:openplayx/capabilities/artwork/artwork_service.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/metadata/metadata_queue_runner.dart';
import 'package:openplayx/capabilities/metadata/providers/tmdb_metadata_plugin.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/core/capabilities/metadata_capability.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/configuration/configuration_database.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/sources/source_config.dart';

import 'support/live_services.dart';
import '../test/support/library_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory scratch;
  setUpAll(() async {
    scratch = await Directory.systemTemp.createTemp('metadata-matching-');
    useAppDataDirectory(scratch);
    // Same seed import as the App, but into isolated test configuration.
    await DebugSeed.applyAtStartup();
  });
  tearDownAll(() async => scratch.delete(recursive: true));

  for (final locale in [const Locale('en'), const Locale('zh', 'CN')]) {
    testWidgets(
      '${locale.languageCode}: VM SMB season automatically matches and groups all episodes',
      (tester) async {
        final sources = SourceManager();
        await sources.load();
        final library = LibraryService(
          sqlite3.openInMemory(),
          configuration: await ConfigurationDatabase.open(),
        );
        final artwork = ArtworkService(
          sources,
          directory: Directory(
            '${scratch.path}/artwork-${locale.languageCode}',
          ),
          retainedArtwork: () => library.metadata.retainedArtwork,
        );
        final runner = MetadataQueueRunner(library, sources, artwork: artwork);
        addTearDown(() async {
          await runner.dispose();
          await sources.dispose();
          library.close();
        });
        library.metadata.followUiLanguage(locale);
        expect(
          library.metadata.setting('tmdbToken'),
          isNotEmpty,
          reason: 'Use make integration-metadata with a seed containing TMDB credentials',
        );
        final movieSources = sources.configs
            .where(
              (s) => s.kind == SourceKind.smb && s.address.endsWith('/movie'),
            )
            .toList();
        expect(
          movieSources,
          hasLength(1),
          reason: 'Seed must contain the VM movie SMB source',
        );
        final source = movieSources.single;
        final root = await sources.browse(source.id, const BrowseRequest());
        final folder = root.entries.singleWhere(
          (e) => e.isFolder && e.name.startsWith('Modern Family Season 1'),
        );
        final fileSource = library.addFileSource(
          source.id,
          root: folder.ref.id,
          name: folder.name,
        );
        addTearDown(() => library.removeFileSource(fileSource));
        await library.scan(fileSource, sources);
        final episodes = library.db.select(
          'SELECT media_id,name FROM resources ORDER BY name',
        );
        expect(episodes, hasLength(24));

        // Reproduce a durable miss made by the old rule. Upgrading must retry
        // it automatically, without clearing the library or changing filenames.
        library.db.execute(
          "UPDATE metadata_queue SET state='awaitingSelection',error_code='ambiguousMatch'",
        );
        library.metadata.setSetting(
          'nameRule',
          '3/title-alias-year-v3/cover-one-fifth-v2',
        );
        await runner.reconcile();
        expect(
          runner.queue.item(episodes.first['media_id'] as String)!['state'],
          'queued',
        );
        await runner.runBatch(maxItems: 40, budget: const Duration(minutes: 6));

        for (final episode in episodes) {
          final id = episode['media_id'] as String;
          final state = runner.queue.item(id)!;
          expect(
            state['state'],
            'completed',
            reason: '${episode['name']}: ${state['error_code']}',
          );
          final ref = library.metadata.association(id)!;
          expect(ref.provider, 'tmdb');
          expect(ref.kind, MediaKind.episode);
          expect(ref.seriesId, '1421');
          expect(ref.season, 1);
          expect(ref.episode, inInclusiveRange(1, 24));
          expect(library.metadata.confirmed(id), isFalse);
          expect(library.metadata.fields(id)['title'], isNotEmpty);
          expect(
            library.metadata.fields(id)['airDate'],
            matches(r'^\d{4}-\d{2}-\d{2}$'),
          );
        }
        final shows = library.query(contentType: 'series');
        expect(shows, hasLength(1));
        final showId = shows.single['id'] as String;
        expect(library.metadata.association(showId)?.provider, 'tmdb');
        expect(library.metadata.association(showId)?.id, '1421');
        final seasons = library.db.select(
          'SELECT child_id FROM metadata_relations WHERE parent_id=?',
          [showId],
        );
        expect(seasons, hasLength(1));
        final seasonId = seasons.single['child_id'] as String;
        expect(library.metadata.association(seasonId)?.provider, 'tmdb');
        expect(library.metadata.association(seasonId)?.season, 1);
        expect(
          library.db.select(
            'SELECT child_id FROM metadata_relations WHERE parent_id=?',
            [seasonId],
          ),
          hasLength(24),
        );
        expect(
          library.db.select(
            "SELECT state,error_code FROM metadata_queue WHERE state<>'completed'",
          ),
          isEmpty,
        );

        // Verify usable image bytes, not just URLs or successful API search.
        final poster = library.metadata.selectedArtwork(showId, type: 'poster');
        expect(poster, isNotNull);
        expect(await (await artwork.load(poster!)).length(), greaterThan(100));
        final thumbnail = library.metadata.selectedArtwork(
          episodes.first['media_id'] as String,
          type: 'thumbnail',
        );
        expect(thumbnail, isNotNull);
        expect(
          await (await artwork.load(thumbnail!)).length(),
          greaterThan(100),
        );

        // Newly created ancestors get their first fingerprint on this poll
        // and can refresh once. They must never search for another identity.
        int searches() =>
            library.db
                    .select(
                      "SELECT count(*) AS n FROM metadata_jobs WHERE json_extract(input,'\$.query') IS NOT NULL",
                    )
                    .single['n']
                as int;
        final searchCount = searches();
        final showRef = library.metadata.association(showId)!.key;
        final seasonRef = library.metadata.association(seasonId)!.key;
        await runner.reconcile();
        await runner.runBatch();
        expect(searches(), searchCount);
        expect(library.metadata.association(showId)!.key, showRef);
        expect(library.metadata.association(seasonId)!.key, seasonRef);
        // Once those fingerprints are initialized, later polls do no work.
        final jobCount = library.db
            .select('SELECT count(*) AS n FROM metadata_jobs')
            .single['n'];
        await runner.reconcile();
        await runner.runBatch();
        expect(
          library.db
              .select('SELECT count(*) AS n FROM metadata_jobs')
              .single['n'],
          jobCount,
        );
        debugPrint(
          'METADATA_MATCHING ${locale.languageCode}: 24 episodes, one series, one season, images cached',
        );
      },
      timeout: const Timeout(Duration(minutes: 8)),
    );
  }

  testWidgets('two identical original titles still require a user choice', (
    tester,
  ) async {
    // A fixed provider response covers an ambiguity that cannot depend on
    // today's live catalogue. Exercise parsing and the full native queue.
    final configuration = SourceConfigurationService(sqlite3.openInMemory());
    final sources = SourceManager(configuration: configuration);
    final library = LibraryService(sqlite3.openInMemory());
    var fetchedDetails = false;
    final plugin = TmdbMetadataPlugin((path, query) async {
      if (path == '/configuration') return <String, dynamic>{};
      if (path == '/search/tv') {
        return {
          'total_pages': 1,
          'results': [
            for (final year in [2009, 2020])
              {
                'id': year,
                'name': 'Modern Family',
                'original_name': 'Modern Family',
                'first_air_date': '$year-01-01',
              },
          ],
        };
      }
      fetchedDetails = true;
      throw StateError('Ambiguous candidates must not be applied');
    });
    final runner = MetadataQueueRunner(
      library,
      sources,
      registry: MetadataRegistry()..register('tmdb', plugin),
    );
    addTearDown(() async {
      await runner.dispose();
      await sources.dispose();
      configuration.close();
      library.close();
    });
    final media = library.register(
      const SourceEntry(
        ResourceRef('@local', '/Modern Family S01E01 Pilot.mkv'),
        'Modern Family S01E01 Pilot.mkv',
        isFolder: false,
      ),
    );
    addToLibrary(library, media);
    await runner.reconcile();
    await runner.runBatch();
    expect(runner.queue.item(media)!['state'], 'awaitingSelection');
    expect(runner.queue.item(media)!['error_code'], 'ambiguousMatch');
    expect(library.metadata.association(media), isNull);
    expect(fetchedDetails, isFalse);
  });
}
