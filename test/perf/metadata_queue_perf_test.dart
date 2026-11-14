import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/metadata_capability.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/metadata/metadata_queue.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/services/metadata/metadata_queue_runner.dart';
import 'package:sqlite3/sqlite3.dart';

import '../metadata/metadata_background_test.dart'
    show TestArtwork, TestMetadataProvider;
import '../metadata/metadata_page_test.dart' show OfflineSources;

/// Synthetic large-library benchmark for work that runs on the UI isolate.
/// Budgets are deliberately loose (CI noise); they catch O(N^2) regressions
/// such as a missing index, not small slowdowns. Numbers are printed so the
/// run doubles as a profiling tool: `flutter test test/perf`.
const items = 5000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late LibraryService library;
  late OfflineSources sources;
  late TestArtwork artwork;
  late TestMetadataProvider provider;

  int ms(void Function() body) {
    final watch = Stopwatch()..start();
    body();
    return watch.elapsedMilliseconds;
  }

  Future<int> msAsync(Future<void> Function() body) async {
    final watch = Stopwatch()..start();
    await body();
    return watch.elapsedMilliseconds;
  }

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('openplayx-perf-');
    library = LibraryService(
      sqlite3.open('${root.path}/library.sqlite3'),
      watchExternalChanges: false,
    );
    {
      for (var i = 0; i < items; i++) {
        final media = library.register(
          SourceEntry(
            ResourceRef('nas', '/share/Film $i (${1980 + i % 40}).mkv'),
            'Film $i (${1980 + i % 40}).mkv',
            isFolder: false,
          ),
        );
        library.addManual(media);
      }
    }
    sources = OfflineSources();
    provider = TestMetadataProvider();
    artwork = TestArtwork(sources);
  });
  tearDownAll(() async {
    library.close();
    await root.delete(recursive: true);
  });

  MetadataQueueRunner runner() => MetadataQueueRunner(
    library,
    sources,
    registry: MetadataRegistry()..register('tmdb', provider),
    artwork: artwork,
  );

  test('reconcile of $items items stays linear', () async {
    final worker = runner();
    await worker.reconcile(); // first pass inserts everything
    final steady = await msAsync(() => worker.reconcile());
    // ignore: avoid_print
    print('reconcile steady-state: $steady ms');
    expect(steady, lessThan(1500));
  });

  test('claim/finish cycle does not scan the library per item', () {
    final queue = MetadataQueue(library.db);
    const n = 100;
    final total = ms(() {
      for (var i = 0; i < n; i++) {
        final row = queue.claim('perf')!;
        queue.finish(row['media_id'] as String, 'perf', 'completed');
      }
    });
    // ignore: avoid_print
    print('claim+finish: ${(total / n).toStringAsFixed(2)} ms/item');
    expect(total / n, lessThan(25));
    queue.release('perf');
  });

  test('missing indexes are detected as a regression', () {
    // Without these indexes the same queries are the O(N^2) hotspots found in
    // profiling; make sure they exist and are actually used.
    final plan = library.db
        .select(
          "EXPLAIN QUERY PLAN SELECT 1 FROM metadata_queue q WHERE EXISTS(SELECT 1 FROM memberships m WHERE m.media_id=q.media_id)",
        )
        .map((r) => r['detail'] as String)
        .join('\n');
    // memberships is keyed by media_id, so its primary key serves the check.
    expect(plan, contains('INDEX sqlite_autoindex_memberships'));
    final res = library.db
        .select('EXPLAIN QUERY PLAN SELECT * FROM resources WHERE media_id=?', [
          'x',
        ])
        .map((r) => r['detail'] as String)
        .join('\n');
    expect(res, contains('resources_media'));
    // Composite primary keys that do not lead with media_id: library.query()
    // checks them per row, and without an index SQLite rebuilds a temporary
    // automatic index on every call (~600 ms on a 4.6k-item library).
    final indexes = library.db
        .select("SELECT name FROM sqlite_master WHERE type='index'")
        .map((r) => r['name'] as String)
        .toSet();
    expect(
      indexes,
      // memberships / manual_memberships are keyed by media_id already.
      containsAll(['resources_media', 'media_evidence_media']),
    );
  });

  test('batch of background work per-item cost', () async {
    final worker = runner();
    await worker.reconcile();
    const batch = 12;
    final total = await msAsync(() => worker.runBatch(maxItems: batch));
    // ignore: avoid_print
    print('runBatch: ${(total / batch).toStringAsFixed(1)} ms/item');
    expect(total / batch, lessThan(250));
    await worker.dispose();
  });

  test('UI-thread queries stay fast', () {
    final query = ms(() => library.query(offset: 0));
    final cont = ms(() => library.continueWatching());
    final recent = ms(() => library.recentlyPlayed());
    final sourcesList = ms(() => library.fileSources());
    final watch = ms(() => library.checkExternalChanges());
    // ignore: avoid_print
    print(
      'query=$query continue=$cont recent=$recent '
      'fileSources=$sourcesList checkExternal=$watch ms',
    );
    for (final t in [query, cont, recent, sourcesList, watch]) {
      expect(t, lessThan(150));
    }
  });
}
