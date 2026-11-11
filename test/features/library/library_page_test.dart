import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/app/theme/app_theme_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/core/plugins/metadata_capability.dart';
import 'package:openplayx/features/library/metadata_artwork.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/library/library_page.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:sqlite3/sqlite3.dart';

class SeriesSources extends Sources {
  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) async {
    const series = SourceMediaInfo(id: 'show', title: 'Show', kind: 'series');
    const season = SourceMediaInfo(
      id: 'season',
      title: 'Season 1',
      kind: 'season',
      parentId: 'show',
    );
    const episode = SourceMediaInfo(
      id: 'episode',
      title: 'Pilot',
      kind: 'episode',
      parentId: 'season',
      season: 1,
      episode: 1,
    );
    if (request.node == null) {
      return const BrowseResult([
        SourceEntry(
          ResourceRef('s', 'show'),
          'Show',
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
        'one.mp4',
        isFolder: false,
        media: episode,
      ),
    ]);
  }
}

class Sources extends SourceManager {
  @override
  List<SourceConfig> get configs => [
    const SourceConfig(
      id: 's',
      kind: SourceKind.smb,
      name: 'NAS',
      address: 'smb://host/share',
    ),
  ];
  @override
  Future<void> load() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) async =>
      const BrowseResult([
        SourceEntry(
          ResourceRef('s', '/share/film.mp4'),
          'Film.mp4',
          isFolder: false,
        ),
      ]);
}

void main() {
  late LibraryService service;
  setUp(() => service = LibraryService(sqlite3.openInMemory()));
  tearDown(() => service.close());
  testWidgets(
    'background publication updates the visible title and cover without navigation',
    (tester) async {
      final collection = service.create('Movies', type: 'movie');
      final media = service.register(
        const SourceEntry(
          ResourceRef('s', '/raw.mkv'),
          'raw.mkv',
          isFolder: false,
        ),
      );
      service.addManual(collection, media);
      await tester.pumpWidget(
        TestApp(
          home: LibraryPage(sources: Sources(), service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('raw.mkv'), findsOneWidget);
      service.transaction(
        () => service.metadata.apply(
          media,
          const MetadataRecord(
            ref: MetadataRef('tmdb', MediaKind.movie, '1'),
            fields: {'title': '刮削后的影片', 'year': 2014},
            artwork: [
              ArtworkDescriptor(id: 'background-poster', type: 'poster'),
            ],
          ),
          sourceKey: 'tmdb',
          authority: 100,
          expectedRevision: 0,
          operationId: 'background-visible',
          select: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('raw.mkv'), findsNothing);
      expect(find.text('刮削后的影片'), findsOneWidget);
      expect(
        tester.widget<MetadataArtwork>(find.byType(MetadataArtwork)).artwork.id,
        'background-poster',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'poster wall follows file sources, then favorite, search and open a movie',
    (tester) async {
      await tester.pumpWidget(
        TestApp(
          home: LibraryPage(sources: Sources(), service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('还没有文件源。请在「来源」中为连接添加文件夹'), findsOneWidget);
      final binding = service.bind(
        service.defaultLibrary(),
        's',
        name: 'Movies',
      );
      await service.scan(binding, Sources());
      await tester.pumpAndSettle();
      expect(find.text('Film.mp4'), findsOneWidget);
      // Disabling a file source hides its media; enabling brings it back.
      service.setBindingEnabled(binding, false);
      // Change notifications are throttled for 300 ms after a scan.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Film.mp4'), findsNothing);
      service.setBindingEnabled(binding, true);
      // Change notifications are throttled for 300 ms after a scan.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Film.mp4'), findsOneWidget);
      // Favourites are hidden for now.
      expect(find.byTooltip('收藏'), findsNothing);
      // Search is a top-right icon that opens an input dialog.
      expect(find.byType(EditableText), findsNothing);
      await tester.tap(find.byTooltip('搜索库内媒体'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'missing');
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('没有符合条件的媒体'), findsOneWidget);
      await tester.tap(find.byTooltip('搜索库内媒体'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Film.mp4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Film.mp4'));
      await tester.pumpAndSettle();
      // A plain video opens the movie page, with a play action.
      expect(find.text('播放'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('library, history and bindings fit narrow and short layouts', (
    tester,
  ) async {
    final library = service.create('Movies');
    const entry = SourceEntry(
      ResourceRef('s', '/film.mp4'),
      'Film.mp4',
      isFolder: false,
    );
    final media = service.register(entry);
    service.addManual(library, media);
    final resource = service.resources(media).single['id'] as String;
    service.saveProgress(
      resource,
      service.beginSession(resource),
      const Duration(minutes: 2),
      const Duration(minutes: 10),
    );
    for (var i = 0; i < 5; i++) {
      service.bind(library, 's');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in [const Size(320, 480), const Size(760, 320)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        TestApp(
          home: LibraryPage(sources: Sources(), service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('a series opens the episode page, a movie the movie page', (
    tester,
  ) async {
    final sources = SeriesSources();
    final binding = service.bind(service.defaultLibrary(), 's', name: 'TV');
    await service.scan(binding, sources);
    await tester.pumpWidget(
      TestApp(
        home: LibraryPage(sources: sources, service: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    // Series page: episodes are listed, there is no movie play button.
    expect(find.textContaining('Pilot'), findsOneWidget);
    expect(find.text('播放'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  for (final developer in [false, true]) {
    testWidgets('metadata button only shows in developer mode ($developer)', (
      tester,
    ) async {
      final sources = SeriesSources();
      final binding = service.bind(service.defaultLibrary(), 's', name: 'TV');
      await service.scan(binding, sources);
      final appearance = AppThemeController(
        initialLanguage: 'zh-Hans',
        initialDeveloperMode: developer,
      );
      addTearDown(appearance.dispose);
      await tester.pumpWidget(
        OpenPlayXApp(
          appearance: appearance,
          home: LibraryPage(sources: sources, service: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('media-metadata')),
        developer ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
