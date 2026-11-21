import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/features/sources/view/scan_scope_page.dart';
import 'package:openplayx/ui/components/media/content_row.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app_test_host.dart';
import 'source_flow_test.dart' show MemorySources;

class ScopePreviewSources extends MemorySources {
  List<String> extensions = ['mkv'];
  final requests = <BrowseRequest>[];

  @override
  List<String> get scanExtensions => extensions;

  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) async {
    requests.add(request);
    if (request.node != null) return const BrowseResult([]);
    SourceEntry entry(String name, {bool folder = false}) =>
        SourceEntry(ResourceRef(id, '/$name'), name, isFolder: folder);
    if (request.offset > 0) {
      return BrowseResult([
        entry('Second.mkv'),
        entry('Later folder', folder: true),
      ]);
    }
    return BrowseResult([
      entry('Movie.MKV'),
      entry('Videos', folder: true),
      entry('Other.mp4'),
      entry('notes.txt'),
      entry('._Movie.mkv'),
    ], nextOffset: 5);
  }
}

void main() {
  testWidgets('preview follows suffix settings, is inert and follows folders', (
    tester,
  ) async {
    final sources = ScopePreviewSources();
    addTearDown(sources.dispose);
    await tester.pumpWidget(
      TestApp(
        home: ScanScopePage(sources: sources, source: 'nas'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Movie.MKV'), findsOneWidget);
    expect(find.text('Other.mp4'), findsNothing);
    expect(find.text('notes.txt'), findsNothing);
    expect(find.text('._Movie.mkv'), findsNothing);
    final fileRow = tester.widget<ContentRow>(
      find.ancestor(
        of: find.text('Movie.MKV'),
        matching: find.byType(ContentRow),
      ),
    );
    expect(fileRow.onTap, isNull);
    expect(fileRow.onLongPress, isNull);
    await tester.tap(find.text('Movie.MKV'));
    await tester.pumpAndSettle();
    expect(sources.requests, hasLength(1));

    await tester.tap(find.text('加载更多'));
    await tester.pumpAndSettle();
    final rows = tester.widgetList<ContentRow>(find.byType(ContentRow));
    expect(rows.map((row) => (row.title as Text).data), [
      'Videos',
      'Later folder',
      'Movie.MKV',
      'Second.mkv',
    ]);
    await tester.tap(find.text('Videos'));
    await tester.pumpAndSettle();
    expect(find.text('Movie.MKV'), findsNothing);
    expect(find.text('Second.mkv'), findsNothing);
  });

  testWidgets('empty suffix setting shows non-hidden files', (tester) async {
    final sources = ScopePreviewSources()..extensions = [];
    addTearDown(sources.dispose);
    await tester.pumpWidget(
      TestApp(
        home: ScanScopePage(sources: sources, source: 'nas'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Movie.MKV'), findsOneWidget);
    expect(find.text('Other.mp4'), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.text('._Movie.mkv'), findsNothing);
  });

  testWidgets(
    'failed folder clears parent entries and retry enables selection',
    (tester) async {
      final sources = MemorySources();
      addTearDown(sources.dispose);
      await tester.pumpWidget(
        TestApp(
          home: ScanScopePage(
            sources: sources,
            source: 'nas',
            forHome: true,
            requireFolder: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Videos'), findsOneWidget);

      sources.failBrowse = true;
      await tester.tap(find.text('Videos'));
      await tester.pumpAndSettle();
      expect(find.text('测试服务不可用'), findsOneWidget);
      // Only the title remains, not the stale folder row from the parent.
      expect(find.text('Videos'), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsNothing);
      ShadButton submit() => tester.widget<ShadButton>(
        find.widgetWithText(ShadButton, '添加并显示到首页'),
      );
      expect(submit().enabled, isFalse);

      sources.failBrowse = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('测试服务不可用'), findsNothing);
      expect(submit().enabled, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('parent navigation recovers after a folder fails', (
    tester,
  ) async {
    final sources = MemorySources();
    addTearDown(sources.dispose);
    await tester.pumpWidget(
      TestApp(
        home: ScanScopePage(sources: sources, source: 'nas'),
      ),
    );
    await tester.pumpAndSettle();
    sources.failBrowse = true;
    await tester.tap(find.text('Videos'));
    await tester.pumpAndSettle();
    sources.failBrowse = false;
    await tester.tap(find.text('上一级'));
    await tester.pumpAndSettle();
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('测试服务不可用'), findsNothing);
    expect(find.text('上一级'), findsNothing);
  });
}
