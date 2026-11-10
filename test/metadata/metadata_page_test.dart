import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/library/metadata_page.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/services/metadata/metadata_service.dart';

import '../app_test_host.dart';

class OfflineSources extends SourceManager {
  @override
  Future<void> load() async {}
  @override
  Future<void> reload() async {}
}

void main() {
  for (final width in [390.0, 1100.0]) {
    testWidgets(
      'metadata editing and reset preserve resources at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final library = LibraryService(sqlite3.openInMemory());
        final sources = OfflineSources();
        final media = library.register(
          const SourceEntry(
            ResourceRef('@local', '/film.mkv'),
            'Film.2014.mkv',
            isFolder: false,
          ),
        );
        final service = MetadataService(library, sources);
        await tester.pumpWidget(
          TestApp(
            home: MetadataPage(
              library: library,
              sources: sources,
              media: media,
              service: service,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('识别 / 重新匹配'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('修正标题'));
        await tester.tap(find.text('修正标题'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText).last, 'My Film');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
        expect(library.metadata.fields(media)['title'], 'My Film');
        expect(library.metadata.lockedFields(media), contains('title'));
        await tester.ensureVisible(find.text('重置匹配'));
        await tester.tap(find.text('重置匹配'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ShadButton, '重置匹配').last);
        await tester.pumpAndSettle();
        expect(library.metadata.association(media), isNull);
        expect(library.metadata.fields(media)['title'], 'My Film');
        expect(library.resources(media), hasLength(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await service.dispose();
        library.close();
      },
    );
  }
}
