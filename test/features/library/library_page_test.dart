import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/core/plugins/metadata_capability.dart';
import 'package:openplayx/features/library/metadata_artwork.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/library/library_page.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:sqlite3/sqlite3.dart';

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
    'create library, select scope, scan, favorite, search and safely remove',
    (tester) async {
      await tester.pumpWidget(
        TestApp(
          home: LibraryPage(sources: Sources(), service: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('创建第一个媒体库'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Movies');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('电影'));
      await tester.pumpAndSettle();
      final library = service.libraries.single['id'] as String;
      expect(service.libraries.single['type'], 'movie');
      await tester.tap(find.byTooltip('添加来源范围'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NAS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认扫描此范围'));
      await tester.pumpAndSettle();
      expect(find.text('Film.mp4'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('收藏'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('收藏'));
      await tester.pumpAndSettle();
      expect(service.query(library, favorites: true), hasLength(1));
      await tester.ensureVisible(find.byType(EditableText));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('没有符合条件的媒体'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), '');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Film.mp4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Film.mp4'));
      await tester.pumpAndSettle();
      final remove = find.text('从当前库移除（保留原文件和媒体记录）');
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(service.query(library), isEmpty);
      expect(service.db.select('SELECT * FROM resources'), hasLength(1));
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
}
