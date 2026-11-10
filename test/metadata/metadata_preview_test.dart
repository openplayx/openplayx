import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/app/theme/app_theme_controller.dart';
import 'package:openplayx/core/plugins/metadata_capability.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/features/library/metadata_page.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/services/metadata/metadata_service.dart';

import 'metadata_page_test.dart' show OfflineSources;

void main() {
  const output = String.fromEnvironment('OPENPLAYX_METADATA_PREVIEW_DIR');
  testWidgets('export metadata pages for visual inspection', (tester) async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in entry['fonts'] as List) {
        loader.addFont(
          rootBundle.load(Uri.decodeFull(font['asset'] as String)),
        );
      }
      await tester.runAsync(loader.load);
    }
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.runAsync(() => Directory(output).create(recursive: true));
    for (final width in [390.0, 1100.0]) {
      tester.view.physicalSize = Size(width, 850);
      final library = LibraryService(sqlite3.openInMemory());
      final sources = OfflineSources();
      final media = library.register(
        const SourceEntry(
          ResourceRef('@local', '/Film.2014.mkv'),
          'Film.2014.mkv',
          isFolder: false,
        ),
      );
      library.transaction(
        () => library.metadata.apply(
          media,
          MetadataRecord(
            ref: const MetadataRef('tmdb', MediaKind.movie, '157336'),
            fields: const {
              'title': 'Interstellar',
              'year': 2014,
              'overview': 'A team of explorers travel beyond this galaxy to discover whether mankind has a future among the stars.',
            },
          ),
          sourceKey: 'tmdb',
          authority: 100,
          expectedRevision: 0,
          operationId: 'preview',
          select: true,
          userConfirmed: true,
        ),
      );
      final service = MetadataService(library, sources);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: OpenPlayXApp(
            appearance: AppThemeController(initialLanguage: 'en'),
            home: MetadataPage(
              library: library,
              sources: sources,
              media: media,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await File('$output/metadata-${width.toInt()}.png')
            .writeAsBytes(data!.buffer.asUint8List());
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await service.dispose();
      library.close();
    }
  }, skip: output.isEmpty);
}
