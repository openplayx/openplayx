import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:openplayx/features/player/controller/player_orientation_session.dart';
import 'package:openplayx/features/player/model/player_orientation.dart';
import 'package:openplayx/features/player/view/player_page.dart';
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
        await tester.tap(find.byTooltip('Settings & effects'));
        await tester.pumpAndSettle();
        final choices = find.byKey(const Key('rotation-choices'));
        await tester.ensureVisible(choices);
        await tester.pumpAndSettle();
        final area = tester.getSize(find.byKey(const Key('video-gestures')));
        final controls = tester.getSize(
          find.byKey(const Key('player-control-bar')),
        );
        for (final degrees in [90, 180, 270, 0]) {
          await tester.tap(
            find.descendant(
              of: choices,
              matching: find.text(degrees == 0 ? 'Original (0°)' : '$degrees°'),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<RotatedBox>(find.byKey(const Key('video-rotation')))
                .quarterTurns,
            degrees ~/ 90,
          );
          expect(
            tester.getSize(find.byType(PlayerVideoView)),
            degrees % 180 == 0 ? area : area.flipped,
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
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await openPlayer(tester);
        final landscapeButton = find.byTooltip('Switch to landscape');
        expect(find.byTooltip('Switch to portrait'), findsNothing);
        expect(
          tester
              .widget<RotatedBox>(
                find.descendant(
                  of: landscapeButton,
                  matching: find.byType(RotatedBox),
                ),
              )
              .quarterTurns,
          1,
        );
        final rotateAt = tester.getCenter(landscapeButton);
        expect(
          rotateAt.dx,
          greaterThan(tester.getCenter(find.byTooltip('Sleep timer')).dx),
        );
        expect(
          rotateAt.dy,
          greaterThan(tester.getCenter(find.byTooltip('Playback speed')).dy),
        );
        await tester.tap(landscapeButton);
        await tester.pumpAndSettle();
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
        tester.view.physicalSize = const Size(932, 430);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Switch to landscape'), findsNothing);
        final portraitButton = find.byTooltip('Switch to portrait');
        expect(
          tester
              .widget<RotatedBox>(
                find.descendant(
                  of: portraitButton,
                  matching: find.byType(RotatedBox),
                ),
              )
              .quarterTurns,
          0,
        );
        expect(
          tester.getCenter(portraitButton).dx,
          greaterThan(tester.getCenter(find.byTooltip('Playback speed')).dx),
        );
        await tester.tap(portraitButton);
        await tester.pumpAndSettle();
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

  for (final blockedRequest in [1, 2]) {
    testWidgets(
      'stopping completes while orientation request $blockedRequest is pending',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final gate = Completer<void>();
        final calls = <Object?>[];
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            calls.add(call.arguments);
            if (calls.length == blockedRequest) await gate.future;
          }
          return null;
        });
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        });
        final backend = await openPlayer(tester);
        var stopped = false;
        final stopping = tester
            .state<PlayerPageState>(find.byType(PlayerPage))
            .stopPlayback()
            .then((result) => stopped = result);
        await tester.pumpAndSettle();

        expect(stopped, isTrue);
        expect(backend.stops, 1);
        expect(backend.value.status, PlaybackStatus.idle);
        expect(calls, hasLength(blockedRequest));

        gate.complete();
        await stopping;
        await tester.pumpAndSettle();
        expect(calls, hasLength(2));
        expect(calls.last, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
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
    // Narrow windows float the panel over the video instead of docking it.
    expect(tester.getSize(find.byKey(const Key('panel-settings'))).width, 320);
    final choice = find.descendant(
      of: find.byKey(const Key('rotation-choices')),
      matching: find.text('270°'),
    );
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tap(choice);
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

  test(
    'system changes release a manual lock only when following is enabled',
    () async {
      final calls = <Object?>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          calls.add(call.arguments);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final session = PlayerOrientationSession();
      await session.deviceOrientationChanged('portraitUp');
      await session.start(
        followSystem: true,
        current: PlayerScreenOrientation.portrait,
      );
      expect(calls.last, isEmpty);
      await session.apply(PlayerScreenOrientation.landscape);
      final lockedCalls = calls.length;
      await session.deviceOrientationChanged('portraitUp');
      expect(calls, hasLength(lockedCalls));
      await session.deviceOrientationChanged('landscapeLeft');
      expect(calls.last, isEmpty);

      await session.setFollowSystem(false, PlayerScreenOrientation.landscape);
      expect(calls.last, [
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);
      await session.apply(PlayerScreenOrientation.portrait);
      final manualCalls = calls.length;
      await session.deviceOrientationChanged('portraitUp');
      expect(calls, hasLength(manualCalls));
      expect(calls.last, ['DeviceOrientation.portraitUp']);
      await session.setFollowSystem(true, PlayerScreenOrientation.portrait);
      expect(calls.last, isEmpty);

      await session.apply(PlayerScreenOrientation.landscape);
      await session.restore();
      final stoppedCalls = calls.length;
      await session.deviceOrientationChanged('landscapeRight');
      expect(calls, hasLength(stoppedCalls));
      expect(calls.last, isEmpty);
      await session.start(
        followSystem: true,
        current: PlayerScreenOrientation.portrait,
      );
      expect(calls.last, isEmpty);
    },
  );

  test(
    'disabled following locks the starting direction and ignores sensor events',
    () async {
      final calls = <Object?>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          calls.add(call.arguments);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final session = PlayerOrientationSession();
      await session.start(
        followSystem: false,
        current: PlayerScreenOrientation.portrait,
      );
      expect(calls.last, ['DeviceOrientation.portraitUp']);
      await session.deviceOrientationChanged('portraitUp');
      await session.deviceOrientationChanged('landscapeLeft');
      expect(calls, hasLength(1));
      await session.restore();
      expect(calls.last, isEmpty);
    },
  );

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
    await tester.tap(find.byTooltip('Switch to portrait'));
    await tester.pumpAndSettle();
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

  testWidgets('video runs under the cutout while controls avoid the insets', (
    tester,
  ) async {
    const insets = EdgeInsets.fromLTRB(0, 44, 0, 34);
    tester.view.padding = FakeViewPadding(
      top: insets.top * tester.view.devicePixelRatio,
      bottom: insets.bottom * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPadding);
    await openPlayer(tester);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getRect(find.byType(PlayerVideoView)), Offset.zero & screen);
    expect(
      tester.getTopLeft(find.byTooltip('Back')).dy,
      greaterThanOrEqualTo(insets.top),
    );
    final bar = tester.getRect(find.byKey(const Key('player-control-bar')));
    expect(bar.bottom, screen.height);
    expect(
      tester.getBottomLeft(find.byTooltip('Back 10 seconds')).dy,
      lessThanOrEqualTo(screen.height - insets.bottom),
    );
  });
}
