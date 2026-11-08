import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:openplayx/features/player/player_page.dart';
import 'package:openplayx_playback/playback.dart';

class FakeBackend extends PlayerBackend {
  final opened = <Uri>[];
  final seeks = <Duration>[];
  bool released = false;
  bool fail = false;
  @override
  Widget buildVideo() => const SizedBox();
  @override
  Future<void> open(Uri uri) async {
    if (fail) throw StateError('test failure');
    opened.add(uri);
    value = const PlayerSnapshot(
      status: PlaybackStatus.playing,
      duration: Duration(seconds: 60),
      canSeek: true,
    );
  }

  @override
  Future<void> pause() async {
    value = const PlayerSnapshot(status: PlaybackStatus.paused);
  }

  @override
  Future<void> play() async {
    value = const PlayerSnapshot(status: PlaybackStatus.playing);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
  }

  @override
  void dispose() {
    released = true;
    super.dispose();
  }
}

void main() {
  testWidgets(
    'cancel preserves current media; controls pause and release backend',
    (tester) async {
      final backend = FakeBackend();
      var selections = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerPage(
            backend: backend,
            pickMedia: () async => selections++ == 0
                ? LocalMedia(Uri.file('/demo.mp4'), 'demo.mp4')
                : null,
          ),
        ),
      );
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('打开文件'));
      await tester.pumpAndSettle();
      expect(backend.opened, [Uri.file('/demo.mp4')]);
      expect(find.text('demo.mp4'), findsOneWidget);
      await tester.tap(find.text('打开文件'));
      await tester.pumpAndSettle();
      expect(backend.opened.length, 1);
      expect(backend.value.status, PlaybackStatus.playing);
      await tester.tap(find.byTooltip('暂停'));
      await tester.pumpAndSettle();
      expect(find.text('已暂停'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(backend.released, isTrue);
    },
  );

  testWidgets('command failure is visible and a subsequent open recovers', (
    tester,
  ) async {
    final backend = FakeBackend()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerPage(
          backend: backend,
          pickMedia: () async => LocalMedia(Uri.file('/demo.mp4'), 'demo.mp4'),
        ),
      ),
    );
    await tester.tap(find.text('打开文件'));
    await tester.pumpAndSettle();
    expect(find.text('播放操作失败，请重新打开媒体文件。'), findsOneWidget);
    backend.fail = false;
    await tester.tap(find.text('打开文件'));
    await tester.pumpAndSettle();
    expect(find.text('正在播放'), findsOneWidget);
  });

  testWidgets('seek is submitted once after dragging finishes', (tester) async {
    final backend = FakeBackend();
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerPage(
          backend: backend,
          pickMedia: () async => LocalMedia(Uri.file('/demo.mp4'), 'demo.mp4'),
        ),
      ),
    );
    await tester.tap(find.text('打开文件'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(backend.seeks, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(backend.seeks, hasLength(1));
    expect(backend.seeks.single, greaterThan(Duration.zero));
  });
}
