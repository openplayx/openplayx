import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:openplayx/capabilities/artwork/artwork_service.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/core/capabilities/metadata_capability.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/features/library/view/media_detail_page.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:openplayx/ui/tokens/app_spacing.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../app_test_host.dart';
import '../../support/fake_sources.dart';
import '../../support/library_test_helpers.dart';

void main() {
  for (final width in [390.0, 817.0]) {
    testWidgets('movie actions have no flag or reserved gap at width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final library = LibraryService(sqlite3.openInMemory());
      addTearDown(library.close);
      final sources = Sources();
      final id = library.register(
        const SourceEntry(
          ResourceRef('s', '/movie.mkv'),
          'Movie',
          isFolder: false,
        ),
      );
      addToLibrary(library, id);
      library.transaction(
        () => library.metadata.apply(
          id,
          const MetadataRecord(
            ref: MetadataRef('tmdb', MediaKind.movie, '1'),
            fields: {
              'kind': 'movie',
              'title': 'Movie',
              'year': 2017,
              'ratings': {
                'tmdb': {'value': 7.4, 'max': 10},
              },
            },
          ),
          sourceKey: 'tmdb',
          authority: 100,
          expectedRevision: 0,
          operationId: 'movie-actions',
          select: true,
        ),
      );
      var plays = 0;
      await tester.pumpWidget(
        TestApp(
          home: MediaDetailPage(
            service: library,
            sources: sources,
            artwork: ArtworkService(sources),
            media: {'id': id, 'title': 'Movie'},
            play: (_, version) async {
              expect(version.ref.id, '/movie.mkv');
              plays++;
            },
            resourceLabel: (_) => '',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(MediaDetailPage)),
      );
      final play = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == l.play,
      );

      for (final watched in [false, true]) {
        library.setWatched(id, watched);
        await tester.pumpAndSettle();
        expect(find.byIcon(LucideIcons.flag), findsNothing);
        expect(find.byIcon(Icons.flag_rounded), findsNothing);
        expect(find.byTooltip(l.markWatched), findsNothing);
        expect(find.byTooltip(l.markUnwatched), findsNothing);
        expect(play, findsOneWidget);
        expect(find.text('2017'), findsOneWidget);
        final facts = tester.getRect(
          find
              .ancestor(of: find.text('7.4'), matching: find.byType(Wrap))
              .first,
        );
        final button = tester.getRect(play);
        if (width < 640) {
          expect(facts.top - button.bottom, closeTo(AppSpacing.xl, 0.01));
        } else {
          expect(facts.bottom, closeTo(button.bottom, 0.01));
        }
      }

      await tester.tap(play);
      await tester.pumpAndSettle();
      expect(plays, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
