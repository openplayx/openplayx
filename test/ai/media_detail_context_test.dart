import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/features/library/view/media_detail_page.dart';
import 'package:openplayx/capabilities/artwork/artwork_service.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/ui/adaptive/app_page.dart';
import 'package:openplayx/ui/adaptive/assistant_action.dart';
import 'package:sqlite3/sqlite3.dart';

import '../app_test_host.dart';
import '../support/fake_sources.dart';

void main() {
  testWidgets('detail button exports its media and refreshes business state', (
    tester,
  ) async {
    final library = LibraryService(sqlite3.openInMemory());
    final sources = Sources();
    final id = library.register(
      const SourceEntry(
        ResourceRef('@local', '/private/movie.mkv'),
        'Movie',
        isFolder: false,
      ),
    );
    PageContextSource? origin;
    await tester.pumpWidget(
      TestApp(
        home: AssistantAction(
          label: '问问',
          onPressed: () {},
          onContext: (source) => origin = source,
          child: MediaDetailPage(
            service: library,
            sources: sources,
            artwork: ArtworkService(sources),
            media: {'id': id, 'title': 'Movie'},
            play: (_, _) async {},
            resourceLabel: (_) => '',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('问问'), findsOneWidget);
    await tester.tap(find.byTooltip('问问'));
    expect(origin!.read()['pageType'], 'media_detail');
    expect(origin!.read()['entity']['media_id'], id);
    expect(origin!.read()['state'].containsKey('favorite'), isFalse);
    await tester.pumpWidget(const SizedBox());
    library.close();
    expect(tester.takeException(), isNull);
  });
}
