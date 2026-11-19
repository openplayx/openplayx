import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app_shell.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:openplayx/features/assistant/view/assistant_page.dart';
import 'package:openplayx/features/player/view/player_page.dart';
import 'package:sqlite3/sqlite3.dart';

import '../app_test_host.dart';
import '../features/player/player_page_test.dart' show FakeBackend;
import '../support/fake_sources.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final size in [
      const Size(390, 844),
      const Size(320, 640),
      const Size(844, 390),
      const Size(640, 320),
    ]) {
      testWidgets(
        'player assistant follows more settings on $platform at $size',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(() {
            debugDefaultTargetPlatformOverride = null;
            tester.view.reset();
          });
          final landscape = size.width > size.height;
          final insets = landscape
              ? const EdgeInsets.fromLTRB(44, 0, 34, 21)
              : const EdgeInsets.fromLTRB(0, 47, 0, 34);
          final library = LibraryService(sqlite3.openInMemory());
          addTearDown(library.close);
          await tester.pumpWidget(
            TestApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  padding: insets,
                  viewPadding: insets,
                ),
                child: AppShell(
                  library: library,
                  sources: Sources(),
                  backend: FakeBackend(),
                  pickMedia: () async => LocalMedia(
                    Uri.file('/demo.mp4'),
                    'A long movie title that must leave room for both actions.mp4',
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final player = tester.state<PlayerPageState>(
            find.byType(PlayerPage, skipOffstage: false),
          );
          await player.openFile();
          await tester.pumpAndSettle();

          final more = find.byTooltip('更多播放设置');
          final assistant = find.byTooltip('AI 助手');
          // Use the real shell so an accidental second overlay is detected.
          expect(assistant, findsOneWidget);
          expect(more.hitTestable(), findsOneWidget);
          expect(assistant.hitTestable(), findsOneWidget);
          final moreRect = tester.getRect(more);
          final assistantRect = tester.getRect(assistant);
          expect(moreRect.overlaps(assistantRect), isFalse);
          expect(moreRect.right, lessThanOrEqualTo(assistantRect.left));
          expect(moreRect.center.dy, assistantRect.center.dy);
          for (final rect in [moreRect, assistantRect]) {
            expect(rect.width, greaterThanOrEqualTo(44));
            expect(rect.height, greaterThanOrEqualTo(44));
            expect(rect.left, greaterThanOrEqualTo(insets.left));
            expect(rect.right, lessThanOrEqualTo(size.width - insets.right));
            expect(rect.top, greaterThanOrEqualTo(insets.top));
            expect(rect.bottom, lessThanOrEqualTo(size.height - insets.bottom));
          }

          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          expect(more.hitTestable(), findsNothing);
          expect(assistant.hitTestable(), findsNothing);
          // The rotation render box extends behind the persistent controls in
          // portrait. Tap the visible picture below the top bar instead.
          await tester.tapAt(Offset(size.width / 2, moreRect.bottom + 40));
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          expect(more.hitTestable(), findsOneWidget);
          expect(assistant.hitTestable(), findsOneWidget);

          await tester.tap(more);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('panel-more')), findsOneWidget);
          await tester.tapAt(Offset(insets.left + 10, insets.top + 60));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('panel-more')), findsNothing);
          await tester.tap(assistant);
          await tester.pumpAndSettle();
          final view = tester.widget<AssistantView>(find.byType(AssistantView));
          expect(
            view.coordinator.context()['pageContext']['pageType'],
            'player',
          );
          await tester.tap(find.byTooltip('关闭'));
          await tester.pumpAndSettle();
          await tester.tap(more);
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byKey(const Key('panel-more')),
              matching: find.text('锁定'),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('slide-to-unlock')), findsOneWidget);
          expect(more.hitTestable(), findsNothing);
          expect(assistant.hitTestable(), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
