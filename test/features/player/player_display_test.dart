import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:openplayx/features/player/player_orientation.dart';
import 'package:openplayx/features/player/player_page.dart';
import 'package:openplayx_playback/playback.dart';

import 'player_page_test.dart' show FakeBackend;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<FakeBackend> openPlayer(WidgetTester tester) async {
    final backend = FakeBackend();
    await tester.pumpWidget(
      OpenPlayXApp(
        home: PlayerPage(
          backend: backend,
          pickMedia: () async => LocalMedia(
            Uri.parse('https://example.test/demo.mp4'),
            'demo.mp4',
          ),
        ),
      ),
    );
    await tester.state<PlayerPageState>(find.byType(PlayerPage)).openFile();
    await tester.pumpAndSettle();
    return backend;
  }

  Future<void> choose(WidgetTester tester, String menu, String option) async {
    await tester.tap(find.byTooltip(menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option));
    await tester.pumpAndSettle();
  }

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets(
      '$platform rotates only video, preserves its player and swaps layout axes',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final backend = await openPlayer(tester);
        final viewElement = tester.element(find.byType(PlayerVideoView));
        final controls = tester.getSize(
          find.byKey(const Key('player-control-bar')),
        );
        for (final degrees in [90, 180, 270, 0]) {
          await choose(
            tester,
            'Video rotation',
            degrees == 0 ? 'Original (0°)' : '$degrees°',
          );
          expect(
            tester
                .widget<RotatedBox>(find.byKey(const Key('video-rotation')))
                .quarterTurns,
            degrees ~/ 90,
          );
          expect(
            tester.getSize(find.byType(PlayerVideoView)),
            degrees % 180 == 0 ? const Size(800, 600) : const Size(600, 800),
          );
          expect(
            tester.element(find.byType(PlayerVideoView)),
            same(viewElement),
          );
          expect(
            tester.getSize(find.byKey(const Key('player-control-bar'))),
            controls,
          );
          expect(backend.value.status, PlaybackStatus.playing);
        }
        expect(backend.opened, hasLength(1));
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform requests landscape/portrait and restores system on stop',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final calls = <Object?>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'SystemChrome.setPreferredOrientations') {
              calls.add(call.arguments);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await openPlayer(tester);
        await choose(tester, 'Screen orientation', 'Landscape');
        expect(calls.last, [
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.landscapeRight',
        ]);
        expect(
          tester
              .widget<RotatedBox>(find.byKey(const Key('video-rotation')))
              .quarterTurns,
          0,
        );
        await choose(tester, 'Screen orientation', 'Portrait');
        expect(calls.last, ['DeviceOrientation.portraitUp']);
        await tester
            .state<PlayerPageState>(find.byType(PlayerPage))
            .stopPlayback();
        await tester.pumpAndSettle();
        expect(calls.last, isEmpty);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets('narrow desktop exposes rotation in more settings', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await openPlayer(tester);
    await tester.tap(find.byTooltip('More playback settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video rotation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('270°'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RotatedBox>(find.byKey(const Key('video-rotation')))
          .quarterTurns,
      3,
    );
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  test('orientation restore waits for an in-flight change', () async {
    final gate = Completer<void>();
    final calls = <Object?>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        calls.add(call.arguments);
        if (calls.length == 1) await gate.future;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final session = PlayerOrientationSession();
    final change = session.apply(PlayerScreenOrientation.landscape);
    final restore = session.restore();
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(1));
    gate.complete();
    await Future.wait([change, restore]);
    expect(calls.last, isEmpty);
  });
  testWidgets('disposing a mobile player restores the system direction', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          calls.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await openPlayer(tester);
    await choose(tester, 'Screen orientation', 'Portrait');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(calls.last, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'failed orientation requests do not prevent restoring the system',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <Object?>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          calls.add(call.arguments);
          if (calls.length == 1) {
            throw PlatformException(code: 'test-orientation-failure');
          }
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final session = PlayerOrientationSession();
      await expectLater(
        session.apply(PlayerScreenOrientation.landscape),
        throwsA(isA<PlatformException>()),
      );
      await session.restore();
      expect(calls.last, isEmpty);
    },
  );
}
