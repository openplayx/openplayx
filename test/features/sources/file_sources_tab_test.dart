import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/sources/source_page.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart';

class _Sources extends SourceManager {
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

class _BrowseSources extends _Sources {
  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) async =>
      request.node?.id == '/share/sub'
      ? const BrowseResult([
          SourceEntry(
            ResourceRef('s', '/share/sub/inner.mp4'),
            'Inner.mp4',
            isFolder: false,
          ),
        ])
      : const BrowseResult([
          SourceEntry(ResourceRef('s', '/share/sub'), 'Sub', isFolder: true),
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

  testWidgets('file sources are children of their connection in one tree', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: SourcePage(manager: _Sources(), library: service),
      ),
    );
    await tester.pumpAndSettle();
    // No tabs any more: the connection is the parent, its folders the children.
    expect(find.text('连接'), findsNothing);
    expect(find.text('NAS'), findsOneWidget);
    expect(find.byTooltip('重新扫描全部文件源'), findsOneWidget);

    await tester.tap(find.text('添加文件源'));
    await tester.pumpAndSettle();
    // The connection is already known, so the flow goes straight to a folder.
    await tester.tap(find.text('确认扫描此范围'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(ShadDialog),
        matching: find.byType(EditableText),
      ),
      'Movies',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final source = service.fileSources().single;
    expect(source['name'], 'Movies');
    expect(source['library_id'], LibraryService.defaultLibraryId);
    expect(source['status'], '扫描完成');
    expect(service.query(null).single['title'], 'Film.mp4');
    expect(find.text('Movies'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Movies')).dx,
      greaterThan(tester.getTopLeft(find.text('NAS')).dx),
      reason: 'the file source is indented under its connection',
    );

    // Disable hides the media; the row shows the disabled state.
    await tester.tap(find.byTooltip('停用'));
    await tester.pumpAndSettle();
    expect(service.query(null), isEmpty);
    expect(find.textContaining('已停用'), findsOneWidget);
    await tester.tap(find.byTooltip('启用'));
    await tester.pumpAndSettle();
    expect(service.query(null), hasLength(1));

    // Delete keeps resources, only drops automatic membership.
    await tester.tap(find.byTooltip('删除文件源'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();
    expect(service.fileSources(), isEmpty);
    expect(service.query(null), isEmpty);
    expect(service.db.select('SELECT * FROM resources'), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('file source rows fit a narrow phone', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    final library = service.defaultLibrary();
    for (var i = 0; i < 3; i++) {
      service.bind(library, 's', name: 'A fairly long file source name $i');
    }
    await tester.pumpWidget(
      TestApp(
        home: SourcePage(manager: _Sources(), library: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('tapping a file source browses its folders and goes back up', (
    tester,
  ) async {
    service.bind(service.defaultLibrary(), 's', name: 'Movies');
    await tester.pumpWidget(
      TestApp(
        home: SourcePage(manager: _BrowseSources(), library: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();
    expect(find.text('Sub'), findsOneWidget);
    expect(find.text('Film.mp4'), findsOneWidget);
    await tester.tap(find.text('Sub'));
    await tester.pumpAndSettle();
    expect(find.text('Inner.mp4'), findsOneWidget);
    expect(find.text('Film.mp4'), findsNothing);
    await tester.tap(find.text('返回上一级'));
    await tester.pumpAndSettle();
    expect(find.text('Film.mp4'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
