import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/metadata_capability.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/features/settings/scrape_management_section.dart';
import 'package:openplayx/services/artwork/artwork_service.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../app_test_host.dart';
import '../sources/source_flow_test.dart' show MemorySources;

class _FakeArtwork extends ArtworkService {
  _FakeArtwork(super.sources);
  int bytes = 2048;
  @override
  Future<int> cacheBytes() async => bytes;
  @override
  Future<void> clear() async => bytes = 0;
  int trims = 0;
  @override
  Future<void> trim() async => trims++;
}

class _QuotaSources extends MemorySources {
  int mb = 256;
  final changes = <int>[];
  @override
  int get artworkCacheQuotaMb => mb;
  @override
  Future<void> setArtworkCacheQuotaMb(int value) async {
    changes.add(value);
    mb = value;
  }
}

void main() {
  test('sizes are shown in readable units', () {
    expect(ScrapeManagementSection.formatBytes(512), '512 B');
    expect(ScrapeManagementSection.formatBytes(1536), '1.5 KB');
    expect(ScrapeManagementSection.formatBytes(5 * 1024 * 1024), '5.0 MB');
    expect(
      ScrapeManagementSection.formatBytes(3 * 1024 * 1024 * 1024),
      '3.0 GB',
    );
  });

  testWidgets('shows scraped count and size, and clears after confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final library = LibraryService(sqlite3.openInMemory());
    addTearDown(library.close);
    final media = library.register(
      const SourceEntry(
        ResourceRef('s', '/Film.2014.mkv'),
        'Film.2014.mkv',
        isFolder: false,
      ),
    );
    library.addManual(library.create('Films'), media);
    library.transaction(
      () => library.metadata.apply(
        media,
        MetadataRecord(
          ref: const MetadataRef('tmdb', MediaKind.movie, '1'),
          fields: const {'title': 'Film', 'overview': 'Plot'},
        ),
        sourceKey: 'tmdb',
        authority: 100,
        expectedRevision: 0,
        operationId: 'op',
        select: true,
      ),
    );
    final sources = MemorySources();
    final artwork = _FakeArtwork(sources);
    addTearDown(artwork.dispose);
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScrapeManagementSection(
              library: library,
              sources: sources,
              artwork: artwork,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 条'), findsOneWidget);
    expect(find.textContaining('图片缓存 2.0 KB'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scrape-clear')));
    await tester.pumpAndSettle();
    expect(find.text('清除全部刮削信息？'), findsOneWidget);
    // Cancelling keeps everything.
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(library.metadata.scrapedStats().media, 1);

    await tester.tap(find.byKey(const ValueKey('scrape-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ShadButton, '清除全部刮削信息').last);
    // The clear waits briefly so the progress indicator can paint.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(library.metadata.scrapedStats(), (media: 0, bytes: 0));
    expect(find.text('0 条'), findsOneWidget);
    expect(find.text('已清除全部刮削信息。'), findsOneWidget);
    expect(artwork.bytes, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [1000.0, 390.0]) {
    testWidgets('image cache limit is a setting; lowering it trims at once '
        '(width $width)', (tester) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final library = LibraryService(sqlite3.openInMemory());
      addTearDown(library.close);
      final sources = _QuotaSources();
      final artwork = _FakeArtwork(sources);
      addTearDown(artwork.dispose);
      await tester.pumpWidget(
        TestApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScrapeManagementSection(
                library: library,
                sources: sources,
                artwork: artwork,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('图片缓存上限'), findsOneWidget);
      expect(find.textContaining('最早下载的图片'), findsOneWidget);
      expect(find.text('256 MB'), findsOneWidget);

      Future<void> pick(String current, String label) async {
        await tester.tap(find.text(current));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      // Raising the limit only saves it.
      await pick('256 MB', '1 GB');
      expect(sources.changes, [1024]);
      expect(artwork.trims, 0);
      expect(find.text('1 GB'), findsOneWidget);
      // Lowering it also evicts down to the new limit right away.
      await pick('1 GB', '128 MB');
      expect(sources.changes, [1024, 128]);
      expect(artwork.trims, 1);
      expect(find.text('128 MB'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
