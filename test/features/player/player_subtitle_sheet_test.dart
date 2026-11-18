import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:openplayx/features/player/view/player_page.dart';
import 'package:openplayx_playback/playback.dart';

import 'player_page_test.dart' show FakeBackend;

class _SubtitleBackend extends FakeBackend {
  final added = <Uri>[];

  @override
  bool get supportsExternalSubtitles => true;

  @override
  Future<void> addExternalSubtitle(Uri file) async => added.add(file);

  @override
  Future<List<PlayerSubtitleTrack>> getSubtitleTracks() async => [
    ...await super.getSubtitleTracks(),
    for (var i = 0; i < added.length; i++)
      PlayerSubtitleTrack(id: 20 + i, name: 'External ${20 + i}'),
  ];
}

void main() {
  Future<_SubtitleBackend> openPlayer(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.iOS,
    bool landscape = false,
    Future<Uri?> Function()? pickSubtitle,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = landscape
        ? const Size(932, 430)
        : const Size(430, 932);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final backend = _SubtitleBackend();
    await tester.pumpWidget(
      OpenPlayXApp(
        home: PlayerPage(
          backend: backend,
          pickMedia: () async => LocalMedia(Uri.file('/demo.mp4'), 'demo.mp4'),
          pickSubtitle: pickSubtitle ?? () async => null,
        ),
      ),
    );
    await tester.state<PlayerPageState>(find.byType(PlayerPage)).openFile();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Subtitles'));
    await tester.pumpAndSettle();
    return backend;
  }

  testWidgets('subtitle handle closes on tap and downward drag', (
    tester,
  ) async {
    final backend = await openPlayer(tester);
    final panel = find.byKey(const Key('panel-subtitles'));
    final handle = find.byKey(const Key('panel-handle'));
    expect(panel, findsOneWidget);
    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);

    await tester.tap(find.byTooltip('Subtitles'));
    await tester.pumpAndSettle();
    await tester.drag(handle, const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    await tester.drag(handle, const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(backend.subtitleSelections, isEmpty);
    expect(backend.seeks, isEmpty);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final landscape in [false, true]) {
      testWidgets('$platform external subtitles load and remain selectable '
          '(landscape: $landscape)', (tester) async {
        var picks = 0;
        final file = Uri.file('/external subtitles.srt');
        final backend = await openPlayer(
          tester,
          platform: platform,
          landscape: landscape,
          pickSubtitle: () async => ++picks == 1 ? null : file,
        );
        final add = find.byKey(const Key('add-subtitle-header'));
        final panel = find.byKey(const Key('panel-subtitles'));
        // Cancellation keeps both the sheet and current selection intact.
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(picks, 1);
        expect(backend.added, isEmpty);
        expect(backend.subtitleSelections, isEmpty);
        expect(panel, findsOneWidget);

        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(picks, 2);
        expect(backend.added, [file]);
        expect(find.text('external subtitles.srt'), findsWidgets);
        expect(panel, findsOneWidget);

        await tester.tap(find.text('Subtitles off'));
        await tester.pumpAndSettle();
        expect(backend.subtitleSelections.last, isNull);
        final external = find.descendant(
          of: panel,
          matching: find.text('external subtitles.srt'),
        );
        await tester.ensureVisible(external);
        await tester.pumpAndSettle();
        await tester.tap(external);
        await tester.pumpAndSettle();
        expect(backend.subtitleSelections.last, 20);
        expect(backend.added, [file]);
        await tester.ensureVisible(find.text('简体中文'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('简体中文'));
        await tester.pumpAndSettle();
        expect(backend.subtitleSelections.last, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
