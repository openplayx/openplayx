import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/metadata/metadata_queue.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/services/artwork/artwork_service.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/services/metadata/metadata_background.dart';
import 'package:workmanager/workmanager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android worker imports metadata and caches artwork without a page',
    (tester) async {
      // A separate compile-time database keeps the installed app's library intact.
      expect(metadataDatabaseName, 'metadata_workmanager_test.sqlite3');
      final root = await Directory.systemTemp.createTemp('metadata-worker-');
      final sources = SourceManager();
      final library = await LibraryService.open(
        databaseName: metadataDatabaseName,
        watchExternalChanges: false,
      );
      final id = 'worker-${DateTime.now().microsecondsSinceEpoch}';
      final work = Workmanager();
      final artwork = ArtworkService(sources);
      addTearDown(() async {
        await work.cancelByUniqueName(id);
        await sources.remove(id);
        artwork.dispose();
        await sources.dispose();
        library.close();
        await root.delete(recursive: true);
      });
      await File('${root.path}/raw.mkv').writeAsBytes([0]);
      await File('${root.path}/raw.nfo').writeAsString(
        '<movie><title>后台已识别影片</title><year>2014</year>'
        '<plot>Native WorkManager integration</plot><thumb>poster.png</thumb></movie>',
      );
      await File('${root.path}/poster.png').writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6zX8AAAAASUVORK5CYII=',
        ),
      );
      await sources.save(
        SourceConfig(
          id: id,
          kind: SourceKind.local,
          name: 'Worker fixture',
          address: root.path,
        ),
        '',
      );
      final media = library.register(
        SourceEntry(
          ResourceRef(id, '${root.path}/raw.mkv'),
          'raw.mkv',
          isFolder: false,
        ),
      );
      library.addManual(media);
      expect(library.query().single['title'], 'raw.mkv');
      await work.initialize(metadataCallbackDispatcher);
      await work.registerOneOffTask(id, metadataCollectTask);
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 90));
        while (DateTime.now().isBefore(deadline)) {
          final info = await work.getWorkInfo(id);
          if (info?.state == WorkState.succeeded) break;
          if (info?.state == WorkState.failed) fail('Native worker failed');
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      });
      expect((await work.getWorkInfo(id))?.state, WorkState.succeeded);
      final queued = MetadataQueue(library.db).item(media)!;
      expect(
        queued['state'],
        'completed',
        reason: queued['error_code'] as String?,
      );
      expect(library.query().single['title'], '后台已识别影片');
      final poster = library.metadata.displayArtwork(media)!;
      // Check the worker published the cache file before the UI tries to load it.
      await File('${root.path}/poster.png').delete();
      final cached = await artwork.load(poster);
      expect(await cached.exists(), isTrue);
      expect(await cached.length(), greaterThan(0));
    },
    skip: !Platform.isAndroid,
  );
}
