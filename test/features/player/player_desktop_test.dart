import '../../app_test_host.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:openplayx/features/player/player_page.dart';
import 'package:openplayx/features/player/window_fullscreen.dart';
import 'package:openplayx_playback/playback.dart';

import 'player_page_test.dart' show FakeBackend;

/// Desktop layout (design §3): Windows, macOS and Linux share it.
void main() {
  late List<bool> fullscreenCalls;
  setUp(() => fullscreenCalls = []);

  Future<FakeBackend> openDesktop(
    WidgetTester tester, {
    Size size = const Size(800, 600),
    TargetPlatform platform = TargetPlatform.macOS,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const channel = MethodChannel('openplayx/window-test');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'setFullScreen') {
        fullscreenCalls.add(call.arguments as bool);
        return call.arguments;
      }
      return false;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final backend = FakeBackend();
    await tester.pumpWidget(
      TestApp(
        home: PlayerPage(
          backend: backend,
          fullscreen: WindowFullscreen(channel: channel),
          pickMedia: () async => LocalMedia(Uri.file('/demo.mp4'), 'demo.mp4'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.state<PlayerPageState>(find.byType(PlayerPage)).openFile();
    await tester.pumpAndSettle();
    return backend;
  }

  Offset videoSpot(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(const Key('video-gestures'))) +
      const Offset(300, 250);

  testWidgets('click pauses, double click toggles full screen, Escape leaves '
      'full screen before the player', (tester) async {
    final backend = await openDesktop(tester);
    await tester.tapAt(videoSpot(tester));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(backend.value.status, PlaybackStatus.paused);

    await tester.tapAt(videoSpot(tester));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(videoSpot(tester));
    await tester.pumpAndSettle();
    expect(fullscreenCalls, [true]);
    expect(backend.value.status, PlaybackStatus.paused);
    expect(find.byTooltip('退出全屏'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(fullscreenCalls, [true, false]);
    expect(find.byType(PlayerPage), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(fullscreenCalls.last, isTrue);
  });

  testWidgets('wheel sets volume; Shift+wheel seeks 3 seconds', (tester) async {
    final backend = await openDesktop(tester);
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.playing,
      position: Duration(seconds: 30),
      duration: Duration(minutes: 5),
      canSeek: true,
      volume: 50,
    );
    await tester.pump();
    final at = videoSpot(tester);
    tester.binding.handlePointerEvent(
      PointerScrollEvent(position: at, scrollDelta: const Offset(0, -40)),
    );
    await tester.pump();
    expect(backend.volumes.last, 55);
    tester.binding.handlePointerEvent(
      PointerScrollEvent(position: at, scrollDelta: const Offset(40, 0)),
    );
    await tester.pump();
    expect(backend.seeks.last, const Duration(seconds: 33));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('right click opens the full menu with shortcuts', (tester) async {
    await openDesktop(tester);
    await tester.tapAt(videoSpot(tester), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('停止'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
    expect(find.text('视频'), findsOneWidget);
    expect(find.text('字幕'), findsOneWidget);
    expect(find.text('⌘O'), findsOneWidget);
  });

  testWidgets('hovering the seek bar shows the target time', (tester) async {
    final backend = await openDesktop(tester);
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.playing,
      position: Duration(seconds: 30),
      duration: Duration(minutes: 10),
      canSeek: true,
    );
    await tester.pump();
    final bar = tester.getRect(find.byKey(const Key('playback-progress')));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: bar.centerLeft + const Offset(1, 0));
    await mouse.moveTo(bar.center);
    await tester.pump();
    expect(find.byKey(const Key('seek-hover-label')), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
  });

  testWidgets('settings panel docks beside the video on wide windows', (
    tester,
  ) async {
    final backend = await openDesktop(tester, size: const Size(1280, 720));
    await tester.tap(find.byTooltip('设置与效果'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('panel-settings'))).width, 360);
    expect(
      tester.getSize(find.byKey(const Key('video-gestures'))).width,
      1280 - 360,
    );
    await tester.tap(find.text('同步'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subtitle-delay-plus')));
    await tester.pumpAndSettle();
    expect(backend.subtitleDelays, [const Duration(milliseconds: 50)]);
    expect(
      find.byKey(const Key('tab-modified-SettingsTab.sync')),
      findsOneWidget,
    );
    await tester.tap(find.text('画面'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('填充'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('tab-modified-SettingsTab.picture')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panel-settings')), findsNothing);
    expect(tester.getSize(find.byKey(const Key('video-gestures'))).width, 1280);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('? shows the shortcut sheet; tracks and speed popovers', (
    tester,
  ) async {
    final backend = await openDesktop(tester, platform: TargetPlatform.windows);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panel-help')), findsOneWidget);
    expect(find.text('Ctrl+T'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panel-help')), findsNothing);

    await tester.tap(find.byTooltip('音轨与字幕'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中文'));
    await tester.pumpAndSettle();
    expect(backend.audioSelections, [3]);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('播放速度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2×'));
    await tester.pumpAndSettle();
    expect(backend.speeds.last, 2);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('zoom, fit and aspect changes keep the native video view', (
    tester,
  ) async {
    final backend = await openDesktop(tester);
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.playing,
      duration: Duration(minutes: 1),
      canSeek: true,
      videoSize: Size(1920, 800),
    );
    await tester.pump();
    final view = tester.element(find.byType(PlayerVideoView));
    for (final key in [
      LogicalKeyboardKey.keyZ,
      LogicalKeyboardKey.keyO,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyZ,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(tester.element(find.byType(PlayerVideoView)), same(view));
    }
    expect(backend.opened, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('seeking after the end restarts and continues from the target', (
    tester,
  ) async {
    final backend = await openDesktop(tester);
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.ended,
      position: Duration(seconds: 60),
      duration: Duration(seconds: 60),
      canSeek: true,
    );
    await tester.pump();
    final bar = tester.getRect(find.byKey(const Key('playback-progress')));
    await tester.tapAt(bar.centerLeft + Offset(bar.width * 0.5, 0));
    await tester.pump();
    // FakeBackend.play reports "playing" without a duration; give it one.
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.playing,
      duration: Duration(seconds: 60),
      canSeek: true,
    );
    await tester.pump();
    expect(backend.seeks.last.inSeconds, inInclusiveRange(29, 31));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a seek while paused keeps showing its target until playback', (
    tester,
  ) async {
    final backend = await openDesktop(tester);
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.paused,
      position: Duration(seconds: 10),
      duration: Duration(seconds: 60),
      canSeek: true,
    );
    await tester.pump();
    final bar = tester.getRect(find.byKey(const Key('playback-progress')));
    await tester.tapAt(bar.centerLeft + Offset(bar.width * 0.5, 0));
    // VLCKit reports no new time while paused.
    await tester.pump(const Duration(seconds: 3));
    String shown() => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const Key('playback-time')),
            matching: find.byType(Text),
          ),
        )
        .data!;
    expect(shown(), startsWith('00:30'));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a hidden (covered or minimised) desktop window keeps playing', (
    tester,
  ) async {
    final backend = await openDesktop(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(backend.value.status, PlaybackStatus.playing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(backend.value.status, PlaybackStatus.paused);
  });

  testWidgets('long media show hours; the tracks popover opens above its '
      'button', (tester) async {
    final backend = await openDesktop(tester, size: const Size(1280, 720));
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.playing,
      position: Duration(minutes: 41, seconds: 22),
      duration: Duration(hours: 2, minutes: 1, seconds: 44),
      canSeek: true,
    );
    await tester.pump();
    expect(find.text('00:41:22 / 02:01:44'), findsOneWidget);
    final button = tester.getRect(find.byTooltip('音轨与字幕'));
    await tester.tap(find.byTooltip('音轨与字幕'));
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byKey(const Key('panel-tracks')));
    expect(panel.bottom, lessThan(button.top));
    expect(panel.left, lessThan(button.center.dx));
    expect(panel.right, greaterThan(button.center.dx));
  });
}
