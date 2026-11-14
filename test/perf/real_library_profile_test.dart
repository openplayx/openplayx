import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/metadata_capability.dart';
import 'package:openplayx/data/metadata/metadata_queue.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/services/metadata/metadata_queue_runner.dart';
import 'package:sqlite3/sqlite3.dart';

import '../metadata/metadata_background_test.dart'
    show TestArtwork, TestMetadataProvider;
import '../metadata/metadata_page_test.dart' show OfflineSources;

/// Profiles a *copy* of a real library database. Skipped unless
/// OPENPLAYX_PERF_DB points at a sqlite file; the file is copied first so the
/// original is never touched:
///   OPENPLAYX_PERF_DB=/path/library.sqlite3 flutter test test/perf/real_library_profile_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = Platform.environment['OPENPLAYX_PERF_DB'];
  test('real library profile', skip: source == null, () async {
    final root = await Directory.systemTemp.createTemp('openplayx-real-');
    addTearDown(() => root.delete(recursive: true));
    final copy = '${root.path}/library.sqlite3';
    File(source!).copySync(copy);
    final library = LibraryService(
      sqlite3.open(copy),
      watchExternalChanges: false,
    );
    addTearDown(library.close);
    final sources = OfflineSources();
    final worker = MetadataQueueRunner(
      library,
      sources,
      registry: MetadataRegistry()..register('tmdb', TestMetadataProvider()),
      artwork: TestArtwork(sources),
    );
    addTearDown(worker.dispose);

    Future<int> t(String name, Future<void> Function() body) async {
      final w = Stopwatch()..start();
      await body();
      // ignore: avoid_print
      print('${name.padRight(28)} ${w.elapsedMilliseconds} ms');
      return w.elapsedMilliseconds;
    }

    // ignore: avoid_print
    print('queue: ${worker.queue.counts}');
    await t('reconcile #1', () => worker.reconcile());
    await t('reconcile #2', () => worker.reconcile());
    await t('library.query', () async => library.query());
    await t('continueWatching', () async => library.continueWatching());
    await t('recentlyPlayed', () async => library.recentlyPlayed());
    await t('fileSources', () async => library.fileSources());
    await t('checkExternalChanges', () async => library.checkExternalChanges());
    await t('queue.pending', () async => worker.queue.pending());
    final q = MetadataQueue(library.db);
    await t('claim+release x20', () async {
      for (var i = 0; i < 20; i++) {
        q.claim('p');
        q.release('p');
      }
    });
    for (final online in [false, true]) {
      final times = <int>[];
      for (var i = 0; i < 4; i++) {
        times.add(
          await t(
            'runBatch(12, online=$online) #$i',
            () => worker.runBatch(allowOnline: online, maxItems: 12),
          ),
        );
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
