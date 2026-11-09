import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:openplayx/features/player/player_page.dart';
import 'package:openplayx_playback/playback.dart';

class FakeBackend extends PlayerBackend {
  final opened = <Uri>[];
  final seeks = <Duration>[];
  final speeds = <double>[];
  final volumes = <int>[];
  final audioSelections = <int>[];
  @override
  Future<void> setSpeed(double speed) async {
    speeds.add(speed);
  }

  @override
  Future<void> setVolume(int volume) async {
    volumes.add(volume);
  }

  @override
  Future<List<PlayerAudioTrack>> getAudioTracks() async => const [
    PlayerAudioTrack(id: 3, name: '中文'),
    PlayerAudioTrack(id: 7, name: 'English'),
  ];
  @override
  Future<void> setAudioTrack(int id) async {
    audioSelections.add(id);
  }

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
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == '播放',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('打开文件'));
      await tester.pumpAndSettle();
      expect(backend.opened, [Uri.file('/demo.mp4')]);
      expect(find.text('demo.mp4'), findsOneWidget);
      await tester.tap(find.byTooltip('打开文件'));
      await tester.pumpAndSettle();
      expect(backend.opened.length, 1);
      expect(backend.value.status, PlaybackStatus.playing);
      await tester.tap(find.byTooltip('暂停'));
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.paused);
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
    await tester.tap(find.byTooltip('打开文件'));
    await tester.pumpAndSettle();
    expect(find.text('播放操作失败，请重新打开媒体文件。'), findsOneWidget);
    backend.fail = false;
    await tester.tap(find.byTooltip('打开文件'));
    await tester.pumpAndSettle();
    expect(backend.value.status, PlaybackStatus.playing);
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
    await tester.tap(find.byTooltip('打开文件'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('playback-progress'))),
    );
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(backend.seeks, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(backend.seeks, hasLength(1));
    expect(backend.seeks.single, greaterThan(Duration.zero));
  });
  Future<void> openPlayer(WidgetTester tester, FakeBackend backend) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerPage(
          backend: backend,
          pickMedia: () async => LocalMedia(Uri.file('/demo.mp4'), 'demo.mp4'),
        ),
      ),
    );
    await tester.tap(find.byTooltip('打开文件'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'skip clamps at both ends and unknown duration disables seeking',
    (tester) async {
      final backend = FakeBackend();
      await openPlayer(tester, backend);
      await tester.tap(find.byTooltip('快退 10 秒'));
      await tester.pumpAndSettle();
      expect(backend.seeks.last, Duration.zero);
      backend.value = const PlayerSnapshot(
        status: PlaybackStatus.playing,
        position: Duration(seconds: 58),
        duration: Duration(seconds: 60),
        canSeek: true,
      );
      await tester.pump();
      expect(find.text('剩余 00:02'), findsOneWidget);
      await tester.tap(find.byTooltip('快进 10 秒'));
      await tester.pumpAndSettle();
      expect(backend.seeks.last, const Duration(seconds: 60));
      backend.value = const PlayerSnapshot(status: PlaybackStatus.playing);
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == '快进 10 秒',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('--:--'), findsOneWidget);
    },
  );

  testWidgets(
    'temporary speed restores persistent choice on release and cancel',
    (tester) async {
      final backend = FakeBackend();
      await openPlayer(tester, backend);
      await tester.tap(find.byTooltip('播放速度'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.5×').last);
      await tester.pumpAndSettle();
      expect(backend.speeds.last, 1.5);
      var gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('video-gestures'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(backend.speeds.last, 2);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(backend.speeds.last, 1.5);
      gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('video-gestures'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(backend.speeds.last, 1.5);
    },
  );

  testWidgets('lock hides controls and blocks long press until unlocked', (
    tester,
  ) async {
    final backend = FakeBackend();
    await openPlayer(tester, backend);
    await tester.tap(find.byTooltip('锁定控制'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('播放速度'), findsNothing);
    expect(find.byTooltip('打开文件'), findsNothing);
    final count = backend.speeds.length;
    await tester.longPress(find.byKey(const Key('video-gestures')));
    await tester.pumpAndSettle();
    expect(backend.speeds.length, count);
    await tester.tap(find.byTooltip('解锁控制'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('暂停'), findsOneWidget);
  });

  testWidgets('volume, video dimming and native audio track ids are wired', (
    tester,
  ) async {
    final backend = FakeBackend();
    await openPlayer(tester, backend);
    expect(find.byKey(const Key('playback-volume')), findsNothing);
    await tester.tap(find.byTooltip('播放器音量'));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('playback-volume'))),
    );
    await tester.pumpAndSettle();
    expect(backend.volumes.last, inInclusiveRange(40, 60));
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('画面亮度'));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('playback-brightness'))),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('video-dimming'))).color.a,
      greaterThan(0),
    );
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('音轨'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(backend.audioSelections, [7]);
  });

  testWidgets('backgrounding restores speed and pauses active playback', (
    tester,
  ) async {
    final backend = FakeBackend();
    await openPlayer(tester, backend);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('video-gestures'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(backend.speeds.last, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(backend.speeds.last, 1);
    expect(backend.value.status, PlaybackStatus.paused);
    await gesture.up();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  });

  testWidgets('controls fit narrow portrait and short landscape layouts', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    for (final size in [const Size(320, 640), const Size(640, 320)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(const SizedBox());
      await openPlayer(tester, FakeBackend());
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'controls overlay the video and hide after inactivity without shrinking it',
    (tester) async {
      final backend = FakeBackend();
      await openPlayer(tester, backend);
      final videoSize = tester.getSize(find.byKey(const Key('video-gestures')));
      expect(videoSize, const Size(800, 600));
      expect(
        tester.getSize(find.byKey(const Key('player-control-bar'))).height,
        lessThan(112),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byTooltip('暂停').hitTestable(), findsNothing);
      expect(
        tester.getSize(find.byKey(const Key('video-gestures'))),
        videoSize,
      );
      await tester.tap(find.byKey(const Key('video-gestures')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('暂停').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('播放速度'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('1.5×'), findsOneWidget);
      await tester.tap(find.text('1.5×'));
      await tester.pumpAndSettle();
      expect(backend.speeds.last, 1.5);
    },
  );

  testWidgets('narrow layout keeps secondary controls in the more menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await openPlayer(tester, FakeBackend());
    expect(find.byTooltip('音轨'), findsNothing);
    expect(find.byKey(const Key('playback-volume')), findsNothing);
    await tester.tap(find.byTooltip('更多播放设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('锁定控制'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('解锁控制'), findsOneWidget);
  });
}
