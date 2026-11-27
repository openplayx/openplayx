import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:openplayx/features/player/view/player_page.dart';

import 'subtitle_alignment_controller_test.dart' show Backend;

void main() {
  for (final layout in [
    (TargetPlatform.macOS, const Size(1280, 800)),
    (TargetPlatform.android, const Size(393, 852)),
    (TargetPlatform.iOS, const Size(852, 393)),
  ]) {
    testWidgets(
      'alignment navigation, fixed footer and manual undo on ${layout.$1} ${layout.$2}',
      (tester) async {
        debugDefaultTargetPlatformOverride = layout.$1;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = layout.$2;
        addTearDown(() {
          tester.view.resetDevicePixelRatio();
          tester.view.resetPhysicalSize();
        });
        final backend = Backend();
        await tester.pumpWidget(
          OpenPlayXApp(
            home: PlayerPage(
              backend: backend,
              pickMedia: () async =>
                  LocalMedia(Uri.file('/demo.mp4'), 'demo.mp4'),
            ),
          ),
        );
        await tester.state<PlayerPageState>(find.byType(PlayerPage)).openFile();
        await tester.pumpAndSettle();
        final mobile = layout.$1 != TargetPlatform.macOS;
        await tester.tap(
          find.byTooltip(mobile ? 'Subtitles' : 'Audio & subtitles'),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('open-subtitle-alignment')),
        );
        await tester.tap(find.byKey(const Key('open-subtitle-alignment')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('panel-alignment')), findsOneWidget);
        expect(tester.takeException(), isNull);
        final footer = tester.getRect(
          find.byKey(const Key('alignment-primary')),
        );
        final panel = tester.getRect(find.byKey(const Key('panel-alignment')));
        expect(footer.bottom, lessThanOrEqualTo(panel.bottom));
        expect(footer.top, greaterThan(panel.top));
        await tester.tap(find.text('Manual offset'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('alignment-delay-1')));
        await tester.tap(find.byKey(const Key('alignment-delay-1')));
        await tester.pumpAndSettle();
        expect(backend.subtitleDelays.last, const Duration(milliseconds: 250));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('alignment-close')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('panel-alignment')), findsNothing);
        // Reopen: manual undo belongs to the playback session, not the sheet.
        await tester.tap(
          find.byTooltip(mobile ? 'Subtitles' : 'Audio & subtitles'),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('open-subtitle-alignment')),
        );
        await tester.tap(find.byKey(const Key('open-subtitle-alignment')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Manual offset'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Return to original'));
        await tester.tap(find.text('Return to original'));
        await tester.pumpAndSettle();
        expect(backend.subtitleDelays.last, Duration.zero);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
