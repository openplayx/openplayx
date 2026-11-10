import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/player/player_page.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:sqlite3/sqlite3.dart';

import '../app_test_host.dart';
import '../features/library/library_page_test.dart' show Sources;
import '../features/player/player_page_test.dart' show FakeBackend;

void main() {
  testWidgets('AI seek checks exact live session after another media opens', (
    tester,
  ) async {
    final library = LibraryService(sqlite3.openInMemory());
    final key = GlobalKey<PlayerPageState>();
    final backend = FakeBackend();
    await tester.pumpWidget(
      TestApp(
        home: PlayerPage(
          key: key,
          backend: backend,
          sourceManager: Sources(),
          libraryService: library,
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> open(String id) async {
      await key.currentState!.playSelection(
        SourceSelection(
          id,
          PlayableStream(Uri.parse('https://example.test/$id.mp4')),
          ref: ResourceRef('s', id),
        ),
      );
      await tester.pumpAndSettle();
    }

    await open('one');
    final session = key.currentState!.assistantSnapshot()['session_id'];
    expect(session, isNotNull);
    await key.currentState!.assistantControl('seek', {
      'session_id': session,
      'position_ms': 1000,
    });
    expect(backend.seeks.last.inMilliseconds, 1000);
    await open('two');
    expect(key.currentState!.assistantSnapshot()['session_id'], isNot(session));
    await expectLater(
      key.currentState!.assistantControl('seek', {
        'session_id': session,
        'position_ms': 2000,
      }),
      throwsStateError,
    );
    expect(backend.seeks.length, 1);
    final current = key.currentState!.assistantSnapshot()['session_id'];
    await expectLater(
      key.currentState!.assistantControl('seek', {
        'session_id': current,
        'position_ms': 999999,
      }),
      throwsStateError,
    );
    expect(backend.seeks.length, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    library.close();
  });
}
