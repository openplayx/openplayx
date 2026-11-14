import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/features/library/media_detail_page.dart';
import 'package:openplayx/services/artwork/artwork_service.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/ui/adaptive/app_page.dart';
import 'package:openplayx/ui/adaptive/assistant_action.dart';
import 'package:sqlite3/sqlite3.dart';

import '../app_test_host.dart';
import '../features/library/library_page_test.dart' show Sources;

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
          label: 'AI 助手',
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
    expect(find.byTooltip('AI 助手'), findsOneWidget);
    await tester.tap(find.byTooltip('AI 助手'));
    expect(origin!.read()['pageType'], 'media_detail');
    expect(origin!.read()['entity']['media_id'], id);
    expect(origin!.read()['state']['favorite'], false);
    await tester.tap(find.byTooltip('收藏'));
    await tester.pumpAndSettle();
    expect(origin!.read()['state']['favorite'], true);
    await tester.pumpWidget(const SizedBox());
    library.close();
    expect(tester.takeException(), isNull);
  });
}
