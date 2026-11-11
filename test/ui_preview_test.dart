import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/app/app_shell.dart';
import 'package:openplayx/app/theme/app_theme_controller.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:sqlite3/sqlite3.dart';

import 'features/player/player_page_test.dart' show FakeBackend;
import 'features/sources/source_flow_test.dart' show MemorySources;

/// Opt-in reference renders, using bundled fonts and real page composition.
/// flutter test test/ui_preview_test.dart --dart-define=OPENPLAYX_UI_PREVIEW_DIR=/tmp/openplayx-ui
void main() {
  const requestedOutput = String.fromEnvironment('OPENPLAYX_UI_PREVIEW_DIR');
  final output = requestedOutput == 'native-temp'
      ? '${Directory.systemTemp.path}/openplayx-macos-screens'
      : requestedOutput;
  const language = String.fromEnvironment(
    'OPENPLAYX_UI_PREVIEW_LOCALE',
    defaultValue: 'en',
  );
  const desktopOnly = bool.fromEnvironment('OPENPLAYX_UI_PREVIEW_DESKTOP_ONLY');
  testWidgets('export primary pages in both themes and window sizes', (
    tester,
  ) async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map<String, dynamic>>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font
          in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
        loader.addFont(
          rootBundle.load(Uri.decodeFull(font['asset'] as String)),
        );
      }
      await tester.runAsync(loader.load);
    }
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    debugPrint('UI screenshots directory: $output');
    await tester.runAsync(() => Directory(output).create(recursive: true));
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final size in [
        if (!desktopOnly) const Size(390, 844),
        const Size(1200, 800),
      ]) {
        tester.view.physicalSize = size;
        final library = LibraryService(sqlite3.openInMemory());
        final id = library.create('My collection');
        for (final name in [
          'Northern lights.mp4',
          'The quiet coast.mp4',
          'A day in the mountains.mp4',
        ]) {
          final media = library.register(
            SourceEntry(ResourceRef('nas', '/$name'), name, isFolder: false),
          );
          library.addManual(id, media);
          final resource = library.resources(media).single['id'] as String;
          library.saveProgress(
            resource,
            library.beginSession(resource),
            const Duration(minutes: 12),
            const Duration(minutes: 50),
          );
        }
        final sources = MemorySources()
          ..saved.addAll(const [
            SourceConfig(
              id: 'nas',
              kind: SourceKind.smb,
              name: 'Living room NAS',
              address: 'smb://host/media',
            ),
            SourceConfig(
              id: 'plex',
              kind: SourceKind.plex,
              name: 'Plex cinema',
              address: 'https://plex.example.com',
            ),
          ]);
        final appearance = AppThemeController(
          initialMode: mode,
          initialLanguage: language,
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: OpenPlayXApp(
              appearance: appearance,
              home: AppShell(
                library: library,
                sources: sources,
                backend: FakeBackend(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final destination in ['home', 'sources', 'settings']) {
          await tester.tap(find.byKey(ValueKey('nav-$destination')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List();
            await File(
              '$output/${mode.name}-${size.width.toInt()}-$destination.png',
            ).writeAsBytes(bytes);
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        appearance.dispose();
        library.close();
      }
    }
  }, skip: requestedOutput.isEmpty);
}
