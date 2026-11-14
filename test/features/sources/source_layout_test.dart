import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/app/theme/app_theme_controller.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/features/sources/source_page.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../app_test_host.dart';
import 'source_flow_test.dart' show MemorySources;

class _SlowSources extends MemorySources {
  final finish = Completer<void>();
  int requests = 0;

  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) async {
    requests++;
    await finish.future;
    return const BrowseResult([]);
  }
}

void main() {
  testWidgets('source menus fit phones, enlarged text and both themes', (
    tester,
  ) async {
    const output = String.fromEnvironment('OPENPLAYX_SOURCE_PREVIEW_DIR');
    if (output.isNotEmpty) {
      const cjkFont = String.fromEnvironment('OPENPLAYX_SOURCE_PREVIEW_FONT');
      if (cjkFont.isNotEmpty) {
        final bytes = await tester.runAsync(() => File(cjkFont).readAsBytes());
        final loader = FontLoader('PingFang SC')
          ..addFont(Future.value(ByteData.sublistView(bytes!)));
        await tester.runAsync(loader.load);
      }
      final fonts =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final entry in fonts.cast<Map<String, dynamic>>()) {
        final loader = FontLoader(entry['family'] as String);
        for (final font
            in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
          loader.addFont(
            rootBundle.load(Uri.decodeFull(font['asset'] as String)),
          );
        }
        await tester.runAsync(loader.load);
      }
      await tester.runAsync(() => Directory(output).create(recursive: true));
    }
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final viewport in [
        (size: const Size(390, 844), scale: 1.0),
        (size: const Size(320, 800), scale: 2.0),
        (size: const Size(1024, 800), scale: 1.0),
      ]) {
        tester.view.physicalSize = viewport.size;
        tester.platformDispatcher.textScaleFactorTestValue = viewport.scale;
        final library = LibraryService(sqlite3.openInMemory());
        final sources = MemorySources()
          ..saved.addAll(const [
            SourceConfig(
              id: 'nas',
              kind: SourceKind.smb,
              name: '家庭 NAS',
              address: 'smb://host/media',
            ),
            SourceConfig(
              id: 'cloud',
              kind: SourceKind.webdav,
              name: '阿里云盘',
              address: 'https://example.com/dav',
              enabled: false,
            ),
            SourceConfig(
              id: 'local',
              kind: SourceKind.local,
              name: '本机文件',
              address: '/Users/viewer/Downloads',
            ),
          ]);
        library.addFileSource('nas', name: '电影', root: '/video/movies');
        library.addFileSource('nas', name: '剧集', root: '/video/tv');
        library.addFileSource('cloud', name: '收藏', root: '/favorites');
        library.addFileSource('local', name: '下载', root: '~/Downloads');
        final appearance = AppThemeController(
          initialMode: mode,
          initialLanguage: 'zh-Hans',
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: OpenPlayXApp(
              appearance: appearance,
              home: SourcePage(manager: sources, library: library),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('/video/movies'), findsOneWidget);
        expect(find.text('收藏'), findsNothing);

        Future<void> capture(String state) async {
          if (output.isEmpty) return;
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$output/${mode.name}-${viewport.size.width.toInt()}-$state.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('list');
        await tester.tap(find.byKey(const ValueKey('source-menu-nas')));
        await tester.pumpAndSettle();
        expect(find.text('连接详情'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture('menu');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('连接详情'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await sources.dispose();
        appearance.dispose();
        library.close();
      }
    }
  });

  testWidgets(
    'a running scan disables repeat scans and adding another folder',
    (tester) async {
      final library = LibraryService(sqlite3.openInMemory());
      final sources = _SlowSources()
        ..saved.add(
          const SourceConfig(
            id: 'nas',
            kind: SourceKind.smb,
            name: 'NAS',
            address: 'smb://host/media',
          ),
        );
      final first = library.addFileSource('nas', name: 'Movies');
      final second = library.addFileSource('nas', name: 'TV');
      await tester.pumpWidget(
        TestApp(
          home: SourcePage(manager: sources, library: library),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('file-source-scan-$first')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(sources.requests, 1);
      expect(
        tester
            .widget<ShadIconButton>(
              find.byKey(ValueKey('file-source-scan-$second')),
            )
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<ShadButton>(
              find.byKey(const ValueKey('source-add-folder-nas')),
            )
            .enabled,
        isFalse,
      );
      sources.finish.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ShadIconButton>(
              find.byKey(ValueKey('file-source-scan-$second')),
            )
            .enabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await sources.dispose();
      library.close();
    },
  );
}
