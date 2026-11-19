import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/sources/file_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/features/library/controller/home_controller.dart';
import 'package:openplayx/features/library/controller/media_detail_controller.dart';
import 'package:sqlite3/sqlite3.dart';

class ScanSources extends SourceManager {
  List<SourceEntry> entries = [];
  Future<BrowseResult> Function(BrowseRequest)? handler;

  @override
  List<SourceConfig> get configs => const [
    SourceConfig(id: 's', kind: SourceKind.local, name: 'Local', address: '/'),
    SourceConfig(
      id: 'other',
      kind: SourceKind.local,
      name: 'Other',
      address: '/',
    ),
  ];

  @override
  Future<void> load() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) async =>
      handler == null ? BrowseResult(entries) : handler!(request);
}

SourceEntry file(String name, {String source = 's', SourceMediaInfo? media}) =>
    SourceEntry(
      ResourceRef(source, '/$name'),
      name,
      isFolder: false,
      media: media,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LibraryService library;
  late ScanSources sources;
  setUp(() {
    library = LibraryService(sqlite3.openInMemory());
    sources = ScanSources();
  });
  tearDown(() => library.close());

  test('real local rescan removes one of ten files and refreshes home and playback', () async {
    final directory = await Directory.systemTemp.createTemp('scan-reconcile-');
    addTearDown(() => directory.delete(recursive: true));
    final files = [
      for (var i = 0; i < 10; i++)
        await File('${directory.path}/film$i.mp4').writeAsBytes([i]),
    ];
    final local = LocalFolderPlugin(
      SourceConfig(
        id: 's',
        kind: SourceKind.local,
        name: 'Local',
        address: directory.path,
      ),
    );
    sources.handler = (request) =>
        local.browse(request, CallContext.forInstance('s'));
    final binding = library.addFileSource('s');
    await library.scan(binding, sources);
    expect(library.query(), hasLength(10));
    final deleted = library.query().singleWhere(
      (r) => r['title'] == 'film0.mp4',
    );
    final media = deleted['id'] as String;
    final resource = library.resources(media).single['id'] as String;
    final home = HomeController(library);
    final detail = MediaDetailController(service: library, media: deleted);
    addTearDown(home.dispose);
    addTearDown(detail.dispose);
    expect(home.shelves.recentlyAdded, hasLength(10));
    expect(detail.playable, isTrue);
    library.saveProgress(
      resource,
      library.beginSession(resource),
      const Duration(minutes: 1),
      const Duration(minutes: 10),
    );

    final refreshed = Completer<void>();
    home.addListener(() {
      if (home.shelves.recentlyAdded.length == 9 && !refreshed.isCompleted) {
        refreshed.complete();
      }
    });
    await files.first.delete();
    await library.scan(binding, sources);
    await refreshed.future.timeout(const Duration(seconds: 3));
    expect(library.query(), hasLength(9));
    expect(library.query().map((r) => r['id']), isNot(contains(media)));
    expect(library.resources(media), isEmpty);
    expect(library.versions(media), isEmpty);
    expect(library.playableResources(media), isEmpty);
    expect(detail.playable, isFalse);
    expect(library.continueWatching(), isEmpty);
    expect(
      library.db.select('SELECT * FROM memberships WHERE media_id=?', [media]),
      isEmpty,
    );
    expect(
      library.db.select('SELECT * FROM media_evidence WHERE media_id=?', [
        media,
      ]),
      isEmpty,
    );

    // Restoring a file reuses its identity and progress.
    await files.first.writeAsBytes([0]);
    await library.scan(binding, sources);
    expect(library.query(), hasLength(10));
    expect(library.resources(media).single['id'], resource);
    expect(library.checkpoint(resource)?['position'], 60000);
  });

  for (final error in ['offline', 'permissionDenied']) {
    test(
      '$error after a partial page never reconciles unconfirmed files',
      () async {
        sources.entries = [for (var i = 0; i < 10; i++) file('film$i.mp4')];
        final binding = library.addFileSource('s');
        await library.scan(binding, sources);
        final missing =
            library.query().singleWhere((r) => r['title'] == 'film0.mp4')['id']
                as String;
        final resource = library.resources(missing).single['id'] as String;
        sources.handler = (request) async {
          if (request.offset == 0) {
            return BrowseResult(
              sources.entries.skip(1).toList(),
              nextOffset: 9,
            );
          }
          throw PluginException(error, error);
        };
        await expectLater(
          library.scan(binding, sources),
          throwsA(isA<PluginException>()),
        );
        expect(library.query(), hasLength(10));
        expect(library.versions(missing), hasLength(1));
        expect(library.observedMissing(resource), isFalse);
        expect(
          library.db.select('SELECT * FROM media_evidence'),
          hasLength(10),
        );
      },
    );
  }

  test(
    'an unfinished scan retains missing files until its last page succeeds',
    () async {
      sources.entries = [file('one.mp4'), file('two.mp4')];
      final binding = library.addFileSource('s');
      await library.scan(binding, sources);
      final lastPage = Completer<BrowseResult>();
      final waiting = Completer<void>();
      sources.handler = (request) async {
        if (request.offset == 0) {
          return BrowseResult([sources.entries.first], nextOffset: 1);
        }
        waiting.complete();
        return lastPage.future;
      };
      final scan = library.scan(binding, sources);
      await waiting.future;
      expect(library.query(), hasLength(2));
      expect(
        library.db.select('SELECT * FROM evidence WHERE available=0'),
        isEmpty,
      );
      lastPage.complete(const BrowseResult([]));
      await scan;
      expect(library.query(), hasLength(1));
    },
  );

  test('overlapping file sources keep a shared resource until both confirm absence', () async {
    sources.entries = [file('shared.mp4')];
    final first = library.addFileSource('s');
    final second = library.addFileSource('s');
    await library.scan(first, sources);
    await library.scan(second, sources);
    final media = library.query().single['id'] as String;
    sources.entries = [];
    await library.scan(first, sources);
    expect(library.query(), hasLength(1));
    expect(library.versions(media), hasLength(1));
    await library.scan(second, sources);
    expect(library.query(), isEmpty);
    expect(library.versions(media), isEmpty);
  });

  test(
    'missing version leaves another source of the same media playable',
    () async {
      const info = SourceMediaInfo(id: 'film', title: 'Film', kind: 'movie');
      sources.entries = [
        file('one.mp4', media: info),
        file('two.mp4', media: info),
      ];
      final first = library.addFileSource('s');
      await library.scan(first, sources);
      final media = library.query().single['id'] as String;
      expect(library.versions(media), hasLength(2));
      sources.entries = [sources.entries.last];
      await library.scan(first, sources);
      expect(library.query(), hasLength(1));
      expect(library.resources(media).single['name'], 'two.mp4');
      expect(library.versions(media).single['name'], 'two.mp4');

      sources.entries = [file('backup.mp4', source: 'other')];
      final second = library.addFileSource('other');
      await library.scan(second, sources);
      final backup =
          library.query().singleWhere((r) => r['id'] != media)['id'] as String;
      // Independently identified files from different sources form one title.
      for (final id in [media, backup]) {
        library.db.execute(
          'INSERT OR REPLACE INTO metadata_state(media_id,fallback_title,association) VALUES (?,?,?)',
          [id, 'Film', '{"provider":"tmdb","kind":"movie","id":"1"}'],
        );
      }
      sources.entries = [];
      await library.scan(first, sources);
      expect(library.query(), hasLength(1));
      expect(library.versions(media).single['source'], 'other');
      expect(library.versions(media).single['name'], 'backup.mp4');
    },
  );
}
