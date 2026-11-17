import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:openplayx/features/player/view/player_page.dart';
import 'package:openplayx_playback/playback.dart';

import 'player_page_test.dart' show FakeBackend;

Future<FakeBackend> openPlayer(WidgetTester tester) async {
  final backend = FakeBackend();
  await tester.pumpWidget(
    TestApp(
      home: PlayerPage(
        backend: backend,
        pickMedia: () async =>
            LocalMedia(Uri.parse('https://example.test/demo.mp4'), 'demo.mp4'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.state<PlayerPageState>(find.byType(PlayerPage)).openFile();
  await tester.pumpAndSettle();
  return backend;
}

void main() {
  testWidgets(
    'space toggles once per press, even after clicking the file button',
    (tester) async {
      final backend = await openPlayer(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.paused);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.paused);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.playing);
      expect(backend.opened, hasLength(1));
      // K is VLC's audio delay, no longer a second pause key.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.playing);
      expect(backend.audioDelays, [const Duration(milliseconds: 50)]);
    },
  );

  testWidgets('remote centre and separate play/pause keys', (tester) async {
    final backend = await openPlayer(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(backend.value.status, PlaybackStatus.paused);
    // Pause while paused stays paused; Play resumes; Play again is a no-op.
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
    await tester.pumpAndSettle();
    expect(backend.value.status, PlaybackStatus.paused);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
    await tester.pumpAndSettle();
    expect(backend.value.status, PlaybackStatus.playing);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
    await tester.pumpAndSettle();
    expect(backend.value.status, PlaybackStatus.playing);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
    await tester.pumpAndSettle();
    expect(backend.value.status, PlaybackStatus.paused);
  });

  testWidgets('modifier jumps, speed, delays and repeat follow VLC keys', (
    tester,
  ) async {
    final backend = await openPlayer(tester);
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.playing,
      position: Duration(minutes: 10),
      duration: Duration(hours: 1),
      canSeek: true,
    );
    await tester.pump();
    Future<void> press(
      LogicalKeyboardKey key, {
      LogicalKeyboardKey? modifier,
    }) async {
      if (modifier != null) await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(key);
      if (modifier != null) await tester.sendKeyUpEvent(modifier);
      await tester.pump();
    }

    // Tests run on Android: the primary modifier is Control.
    await press(
      LogicalKeyboardKey.arrowRight,
      modifier: LogicalKeyboardKey.shiftLeft,
    );
    await press(
      LogicalKeyboardKey.arrowLeft,
      modifier: LogicalKeyboardKey.controlLeft,
    );
    await press(
      LogicalKeyboardKey.arrowRight,
      modifier: LogicalKeyboardKey.altLeft,
    );
    // The fake never reports the seek, so quick presses chain from the
    // pending target (they must not all start from the stale 10:00).
    expect(backend.seeks, [
      const Duration(minutes: 10, seconds: 3),
      const Duration(minutes: 9, seconds: 3),
      const Duration(minutes: 9, seconds: 13),
    ]);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(backend.seeks.last, const Duration(minutes: 14, seconds: 13));

    await press(LogicalKeyboardKey.bracketRight);
    await press(
      LogicalKeyboardKey.equal,
      modifier: LogicalKeyboardKey.shiftLeft,
    );
    await press(LogicalKeyboardKey.minus);
    await press(LogicalKeyboardKey.equal);
    await tester.pumpAndSettle();
    expect(backend.speeds.skip(1), [1.05, 1.25, 1.0, 1.0]);

    await press(LogicalKeyboardKey.keyH);
    await press(LogicalKeyboardKey.keyH);
    await press(LogicalKeyboardKey.keyG);
    await press(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();
    expect(backend.subtitleDelays, [
      const Duration(milliseconds: 50),
      const Duration(milliseconds: 100),
      const Duration(milliseconds: 50),
    ]);
    expect(backend.audioDelays, [const Duration(milliseconds: -50)]);
    // Status chips show the offsets.
    expect(find.text('+0.05 s'), findsOneWidget);
    expect(find.text('-0.05 s'), findsOneWidget);

    await press(LogicalKeyboardKey.keyL);
    await tester.pumpAndSettle();
    expect(find.text('单项循环'), findsWidgets); // OSD and status chip
    backend.value = const PlayerSnapshot(status: PlaybackStatus.ended);
    await tester.pumpAndSettle();
    expect(backend.value.status, PlaybackStatus.playing); // replayed

    await press(LogicalKeyboardKey.keyB);
    await tester.pumpAndSettle();
    // Nothing chosen yet: the first track counts as playing, so next is the
    // second one.
    expect(backend.audioSelections, [7]);
    // Nothing chosen yet (the player's default is unknown): next is the
    // first subtitle.
    await press(LogicalKeyboardKey.keyV);
    await tester.pumpAndSettle();
    expect(backend.subtitleSelections, [2]);
    await press(
      LogicalKeyboardKey.keyV,
      modifier: LogicalKeyboardKey.shiftLeft,
    );
    await tester.pumpAndSettle();
    expect(backend.subtitleSelections.last, isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Ctrl+T jumps to a typed time; A cycles the aspect ratio', (
    tester,
  ) async {
    final backend = await openPlayer(tester);
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.playing,
      position: Duration(seconds: 5),
      duration: Duration(hours: 2),
      canSeek: true,
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('jump-to-time-input')), 'abc');
    await tester.tap(find.text('跳转'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请输入'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('jump-to-time-input')),
      '1:02:03',
    );
    await tester.tap(find.text('跳转'));
    await tester.pumpAndSettle();
    expect(
      backend.seeks.last,
      const Duration(hours: 1, minutes: 2, seconds: 3),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pumpAndSettle();
    expect(find.text('16:9'), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'arrow keys seek, adjust volume and respect boundaries; M restores volume',
    (tester) async {
      final backend = await openPlayer(tester);
      backend.value = const PlayerSnapshot(
        status: PlaybackStatus.playing,
        position: Duration(seconds: 30),
        duration: Duration(seconds: 60),
        canSeek: true,
        volume: 40,
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pumpAndSettle();
      // ← then → chain from the pending target: back to where it was.
      expect(backend.seeks, [
        const Duration(seconds: 20),
        const Duration(seconds: 30),
      ]);
      expect(backend.volumes, [45, 35, 0]);
      backend.value = const PlayerSnapshot(
        status: PlaybackStatus.playing,
        volume: 0,
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pumpAndSettle();
      expect(backend.volumes.last, 40);
      backend.value = const PlayerSnapshot(
        status: PlaybackStatus.playing,
        volume: 100,
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(backend.volumes.last, 100);
    },
  );

  testWidgets(
    'shortcuts wake hidden controls; lock blocks commands until Escape',
    (tester) async {
      final backend = await openPlayer(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byTooltip('暂停').hitTestable(), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.paused);
      expect(find.byTooltip('播放').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('锁定控制'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.paused);
      expect(backend.seeks, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.playing);
    },
  );

  testWidgets(
    'menus, text entry in other routes and modified keys do not control playback',
    (tester) async {
      final backend = await openPlayer(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.playing);
      await tester.tap(find.byTooltip('播放速度'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(backend.seeks, isEmpty);
      expect(backend.value.status, PlaybackStatus.playing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      final navigator = Navigator.of(tester.element(find.byType(PlayerPage)));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: TextField(autofocus: true)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'hello world');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.playing);
      expect(backend.seeks, isEmpty);
      navigator.pop();
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(150, 300));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.paused);
    },
  );

  testWidgets('quick jumps chain even when the first one is reported early', (
    tester,
  ) async {
    final backend = await openPlayer(tester);
    PlayerSnapshot at(int seconds) => PlayerSnapshot(
      status: PlaybackStatus.playing,
      position: Duration(seconds: seconds),
      duration: const Duration(minutes: 5),
      canSeek: true,
    );
    backend.value = at(10);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    // The player reports the first target while the second is in flight.
    backend.value = at(20);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(backend.seeks, [
      const Duration(seconds: 20),
      const Duration(seconds: 30),
      const Duration(seconds: 40),
    ]);
    // A position far from the chain (another seek path) ends it.
    backend.value = at(200);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(backend.seeks.last, const Duration(seconds: 190));
    await tester.pump(const Duration(seconds: 1));
  });
}
