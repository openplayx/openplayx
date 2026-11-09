import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:openplayx/features/player/player_page.dart';
import 'package:openplayx_playback/playback.dart';

import 'player_page_test.dart' show FakeBackend;

Future<FakeBackend> openPlayer(WidgetTester tester) async {
  final backend = FakeBackend();
  await tester.pumpWidget(
    MaterialApp(
      home: PlayerPage(
        backend: backend,
        pickMedia: () async =>
            LocalMedia(Uri.parse('https://example.test/demo.mp4'), 'demo.mp4'),
      ),
    ),
  );
  await tester.tap(find.byTooltip('打开文件'));
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
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.paused);
    },
  );

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
      expect(backend.seeks, [
        const Duration(seconds: 20),
        const Duration(seconds: 40),
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
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byTooltip('暂停').hitTestable(), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.paused);
      expect(find.byTooltip('播放').hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
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
      await tester.enterText(find.byType(TextField), 'hello world');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.playing);
      expect(backend.seeks, isEmpty);
      navigator.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('video-gestures')));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.paused);
    },
  );
}
