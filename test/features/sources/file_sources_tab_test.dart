import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/sources/file_source_browser_page.dart';
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

  testWidgets('scraping progress follows the scan status of a file source', (
    tester,
  ) async {
    final binding = service.addFileSource('s', name: 'Movies');
    await service.scan(binding, _Sources());
    await tester.pumpWidget(
      TestApp(
        home: SourcePage(manager: _Sources(), library: service),
      ),
    );
    await tester.pumpAndSettle();
    Text status() => tester.widget<Text>(
      find.byKey(ValueKey('file-source-status-$binding')),
    );
    expect(status().data, '扫描完成 · 刮削 0/1');
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    // "Not found" is finished work too.
    service.db.execute("UPDATE metadata_queue SET state='unmatched'");
    service.notifyChanged();
    await tester.pumpAndSettle();
    expect(status().data, '扫描完成 · 刮削完成');
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

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
    expect(find.byTooltip('重新扫描全部文件源'), findsNothing);
    expect(find.byTooltip('重新加载配置'), findsNothing);

    // Adding is visible inline and is also available in the parent menu.
    expect(find.byKey(const ValueKey('source-add-folder-s')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('source-menu-s')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('source-add-file-s')));
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
    expect(source['status'], '扫描完成');
    expect(service.query().single['title'], 'Film.mp4');
    expect(find.text('Movies'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Movies')).dx,
      greaterThan(tester.getTopLeft(find.text('NAS')).dx),
      reason: 'the file source is indented under its connection',
    );

    // Child enable/disable lives in its own menu.
    final id = source['id'] as String;
    await tester.tap(find.byKey(ValueKey('file-source-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('file-source-toggle-$id')));
    await tester.pumpAndSettle();
    expect(service.query(), isEmpty);
    expect(find.textContaining('已停用'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('file-source-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('file-source-toggle-$id')));
    await tester.pumpAndSettle();
    expect(service.query(), hasLength(1));

    // No pencil or trash icons on the row any more.
    expect(find.byTooltip('重命名媒体库'), findsNothing);
    expect(find.byTooltip('删除文件源'), findsNothing);

    // The parent's tap only collapses its children; it does not browse.
    await tester.tap(find.text('NAS'));
    await tester.pumpAndSettle();
    expect(find.text('Movies'), findsNothing);
    expect(find.byType(FileSourceBrowserPage), findsNothing);
    await tester.tap(find.text('NAS'));
    await tester.pumpAndSettle();
    expect(find.text('Movies'), findsOneWidget);

    // Editing a child opens the existing naming flow.
    await tester.tap(find.byKey(ValueKey('file-source-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('file-source-edit-$id')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(ShadDialog),
        matching: find.byType(EditableText),
      ),
      'Films',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(service.fileSources().single['name'], 'Films');

    // Delete asks first; cancelling keeps the source.
    await tester.tap(find.byKey(ValueKey('file-source-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('file-source-delete-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(service.fileSources(), hasLength(1));

    // Delete keeps resources, only drops automatic membership.
    await tester.tap(find.byKey(ValueKey('file-source-menu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('file-source-delete-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();
    expect(service.fileSources(), isEmpty);
    expect(service.query(), isEmpty);
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
    for (var i = 0; i < 3; i++) {
      service.addFileSource('s', name: 'A fairly long file source name $i');
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
    service.addFileSource('s', name: 'Movies');
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
