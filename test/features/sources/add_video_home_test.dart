import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app_shell.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/library/scan_status.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/features/library/view/media_detail_page.dart';
import 'package:openplayx/features/sources/view/source_instance_form.dart';
import 'package:openplayx/features/sources/view/scan_scope_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../app_test_host.dart';
import '../player/player_page_test.dart' show FakeBackend;
import 'source_flow_test.dart' show MemorySources;

class PagedSources extends MemorySources {
  final remaining = Completer<void>();
  bool fail = false;

  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) async {
    if (request.offset > 0) {
      await remaining.future;
      if (fail) throw const PluginException('networkUnavailable', 'Offline');
      return const BrowseResult([]);
    }
    return BrowseResult([
      SourceEntry(ResourceRef(id, '/first.mp4'), 'First.mp4', isFolder: false),
    ], nextOffset: 100);
  }
}

void main() {
  testWidgets(
    'home SMB add shows and plays a raw video before scan completes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final library = LibraryService(sqlite3.openInMemory());
      final sources = PagedSources();
      final backend = FakeBackend();
      addTearDown(library.close);
      addTearDown(sources.dispose);
      await tester.pumpWidget(
        TestApp(
          home: AppShell(backend: backend, sources: sources, library: library),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('home-add-video-empty')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('home-add-video-empty')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-video-smb')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(EditableText).at(1),
        'smb://localhost/Movies',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('source-save')));
      await tester.tap(find.byKey(const ValueKey('source-save')));
      await tester.pumpAndSettle();
      expect(sources.saved, hasLength(1));
      expect(library.fileSources(), hasLength(1));
      expect(library.fileSourceList().single.scanning, isTrue);
      expect(library.continueWatching(), isEmpty);
      expect(find.text('First.mp4'), findsWidgets);
      await tester.tap(find.text('First.mp4').first);
      await tester.pumpAndSettle();
      expect(find.byType(MediaDetailPage), findsOneWidget);
      final play = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == '播放',
      );
      await tester.tap(play);
      await tester.pumpAndSettle();
      expect(backend.opened, [Uri.parse('http://127.0.0.1:18000/session')]);
      sources.remaining.complete();
      await tester.pumpAndSettle();
      expect(library.fileSourceList().single.status, ScanStatus.done);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('saved connection is reused and confirmed without credentials', (
    tester,
  ) async {
    final library = LibraryService(sqlite3.openInMemory());
    final sources = MemorySources()
      ..saved.add(
        const SourceConfig(
          id: 'nas',
          kind: SourceKind.smb,
          name: 'Saved NAS',
          address: 'smb://localhost/Movies',
        ),
      );
    final backend = FakeBackend();
    addTearDown(library.close);
    addTearDown(sources.dispose);
    await tester.pumpWidget(
      TestApp(
        home: AppShell(backend: backend, sources: sources, library: library),
      ),
    );
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.byKey(const ValueKey('home-add-video')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved NAS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加并显示到首页'));
      await tester.pumpAndSettle();
    }
    expect(sources.saved, hasLength(1));
    expect(sources.secrets, isEmpty);
    expect(library.fileSources(), hasLength(1));
    expect(library.query(), hasLength(1));
    expect(find.text('Demo.mp4'), findsWidgets);
    expect(find.text('该范围暂未发现视频。'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('SMB host requires a share and cancellation creates no binding', (
    tester,
  ) async {
    final library = LibraryService(sqlite3.openInMemory());
    final sources = MemorySources();
    addTearDown(library.close);
    addTearDown(sources.dispose);
    await tester.pumpWidget(
      TestApp(
        home: AppShell(
          backend: FakeBackend(),
          sources: sources,
          library: library,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-add-video')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-video-smb')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(1), 'smb://localhost');
    await tester.ensureVisible(find.byKey(const ValueKey('source-save')));
    await tester.tap(find.byKey(const ValueKey('source-save')));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScopePage), findsOneWidget);
    final submit = tester.widget<ShadButton>(
      find.widgetWithText(ShadButton, '添加并显示到首页').last,
    );
    expect(submit.enabled, isFalse);
    expect(library.fileSources(), isEmpty);
    Navigator.of(tester.element(find.byType(ScanScopePage))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SourceInstanceForm), findsOneWidget);
    expect(sources.saved, hasLength(1));
    expect(library.fileSources(), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  for (final picked in <String?>['/selected/Movies', null]) {
    testWidgets('local onboarding opens chooser directly: $picked', (
      tester,
    ) async {
      final sources = MemorySources();
      addTearDown(sources.dispose);
      var picks = 0;
      var submissions = 0;
      await tester.pumpWidget(
        TestApp(
          home: SourceInstanceForm(
            manager: sources,
            initialKind: SourceKind.local,
            chooseDirectory: () async {
              picks++;
              return picked;
            },
            onAddToHome: (_) async {
              submissions++;
              return false;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(picks, 1);
      await tester.ensureVisible(find.byKey(const ValueKey('source-save')));
      await tester.tap(
        find.byKey(const ValueKey('source-save')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(submissions, picked == null ? 0 : 1);
      expect(sources.saved, hasLength(picked == null ? 0 : 1));
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('failed scan beside shelves is one row that expands', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final library = LibraryService(sqlite3.openInMemory());
    final sources = PagedSources()
      ..saved.add(
        const SourceConfig(
          id: 'nas',
          kind: SourceKind.smb,
          name: 'NAS',
          address: 'smb://localhost/Movies',
        ),
      );
    addTearDown(library.close);
    addTearDown(sources.dispose);
    final id = library.addToHome('nas');
    // The first page lands, then the source fails before the rest arrives.
    await tester.runAsync(() async {
      library.startScan(id, sources);
      for (var i = 0; i < 100 && library.query().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    library.repository.markScanFailed('Offline', id);
    expect(library.fileSourceList().single.status, ScanStatus.failed);
    await tester.pumpWidget(
      TestApp(
        home: AppShell(
          backend: FakeBackend(),
          sources: sources,
          library: library,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(ValueKey('home-scan-failed-$id'));
    expect(row, findsOneWidget);
    expect(find.text('First.mp4'), findsWidgets);
    Text reason() => tester.widget<Text>(
      find.descendant(of: row, matching: find.text('Offline')),
    );
    expect(reason().maxLines, 1);
    await tester.tap(find.descendant(of: row, matching: find.text('Offline')));
    await tester.pump();
    expect(reason().maxLines, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'failed traversal retains video and resumes the saved cursor on retry',
    () async {
      final library = LibraryService(sqlite3.openInMemory());
      final sources = PagedSources()
        ..saved.add(
          const SourceConfig(
            id: 'nas',
            kind: SourceKind.smb,
            name: 'NAS',
            address: 'smb://localhost/Movies',
          ),
        );
      addTearDown(library.close);
      addTearDown(sources.dispose);
      final id = library.addToHome('nas');
      library.startScan(id, sources);
      // The durable task exists before any asynchronous discovery completes.
      expect(library.repository.scanTask(id), hasLength(1));
      await Future<void>.delayed(Duration.zero);
      expect(library.query(), hasLength(1));
      sources.fail = true;
      sources.remaining.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(library.fileSourceList().single.status, ScanStatus.failed);
      expect(library.query(), hasLength(1));
      expect(library.continueWatching(), isEmpty);
      sources.fail = false;
      expect(library.addToHome('nas', root: ''), id);
      library.startScan(id, sources);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(library.fileSourceList().single.status, ScanStatus.done);
      expect(library.query(), hasLength(1));
      expect(library.fileSourceMediaCount(id), 1);
      expect(library.repository.scanTask(id), isEmpty);
      library.transaction(() {
        library.repository.insertScanTask(
          id,
          'restart-batch',
          sources.saved.single.revision,
        );
        library.repository.insertScanRoot(id, '');
        library.repository.markScanRunning(id);
      });
      await library.recoverScans(sources);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(library.fileSourceList().single.status, ScanStatus.done);
      expect(library.query(), hasLength(1));
    },
  );
}
