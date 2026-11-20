import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/artwork/artwork_service.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/core/capabilities/metadata_capability.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/features/library/view/media_detail_page.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../app_test_host.dart';
import '../../support/fake_sources.dart';
import '../../support/library_test_helpers.dart';

void main() {
  for (final width in [320.0, 390.0, 817.0, 1280.0]) {
    testWidgets(
      'file details show title, progress and playable source at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final library = LibraryService(sqlite3.openInMemory());
        addTearDown(library.close);
        final sources = Sources();
        const title = '明清之變｜崇禎為什麼一定要殺袁崇煥？袁崇煥死的到底冤不冤：一段很長的影片標題';
        final id = library.register(
          const SourceEntry(
            ResourceRef('s', '/history.mp4'),
            title,
            isFolder: false,
            size: 1073741824,
          ),
        );
        addToLibrary(library, id);
        final resource = library.versionList(id).single;
        library.saveProgress(
          resource.id,
          library.beginSession(resource.id),
          const Duration(minutes: 12),
          const Duration(minutes: 48),
        );
        var plays = 0;
        await tester.pumpWidget(
          TestApp(
            home: MediaDetailPage(
              service: library,
              sources: sources,
              artwork: ArtworkService(sources),
              media: {'id': id, 'title': title},
              play: (_, version) async {
                expect(version.id, resource.id);
                plays++;
              },
              resourceLabel: (_) => '家庭 NAS',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('media-file-details')),
          findsOneWidget,
        );
        final heading = tester.widget<Text>(
          find.byKey(const ValueKey('media-file-title')),
        );
        expect(heading.data, title);
        expect(heading.maxLines, isNull);
        expect(find.text('12:00 / 48:00'), findsOneWidget);
        expect(find.textContaining('家庭 NAS'), findsOneWidget);
        expect(find.textContaining('GB'), findsOneWidget);
        final resume = find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == '继续观看',
        );
        await tester.ensureVisible(resume);
        await tester.tap(resume);
        await tester.pumpAndSettle();
        expect(plays, 1);
        final filePlay = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == '播放: $title',
        );
        await tester.ensureVisible(filePlay);
        await tester.tap(filePlay);
        await tester.pumpAndSettle();
        expect(plays, 2);
        expect(tester.takeException(), isNull);

        // A background match replaces the file layout without reopening the page.
        library.transaction(
          () => library.metadata.apply(
            id,
            const MetadataRecord(
              ref: MetadataRef('tmdb', MediaKind.movie, '123'),
              fields: {'title': 'Matched movie', 'overview': 'Movie synopsis'},
            ),
            sourceKey: 'tmdb',
            authority: 100,
            expectedRevision: library.metadata.revision(id),
            operationId: 'match',
            select: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('media-file-details')), findsNothing);
        expect(find.text('Matched movie'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
