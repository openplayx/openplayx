import '../../app_test_host.dart';

import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:openplayx/data/remote_access/remote_transport.dart';
import 'package:openplayx/features/player/view/player_page.dart';
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

  final subtitleSelections = <int?>[];
  @override
  Future<List<PlayerSubtitleTrack>> getSubtitleTracks() async => const [
    PlayerSubtitleTrack(id: 2, name: '简体中文', language: 'zh'),
    PlayerSubtitleTrack(id: 5, name: 'English', language: 'en'),
  ];
  @override
  Future<void> setSubtitleTrack(int id) async {
    subtitleSelections.add(id);
  }

  @override
  Future<void> disableSubtitle() async {
    subtitleSelections.add(null);
  }

  final audioDelays = <Duration>[];
  final subtitleDelays = <Duration>[];
  @override
  bool get supportsDelays => true;
  @override
  Future<void> setAudioDelay(Duration delay) async => audioDelays.add(delay);
  @override
  Future<void> setSubtitleDelay(Duration delay) async =>
      subtitleDelays.add(delay);
  @override
  bool get supportsMediaInfo => true;
  @override
  Future<PlayerMediaInfo> getMediaInfo() async => const PlayerMediaInfo(
    tracks: [PlayerTrackInfo(type: 'video', codec: 'h264')],
  );
  @override
  Future<PlayerStats?> getStats() async => const PlayerStats(inputKbps: 4200);

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

  int stops = 0;
  @override
  Future<void> stop() async {
    stops++;
    value = const PlayerSnapshot();
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
        TestApp(
          home: PlayerPage(
            backend: backend,
            pickMedia: () async => selections++ == 0
                ? LocalMedia(Uri.file('/demo.mp4'), 'demo.mp4')
                : null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ShadIconButton>(
              find.descendant(
                of: find.byTooltip('播放'),
                matching: find.byType(ShadIconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.state<PlayerPageState>(find.byType(PlayerPage)).openFile();
      await tester.pumpAndSettle();
      expect(backend.opened, [Uri.file('/demo.mp4')]);
      expect(find.text('demo.mp4'), findsOneWidget);
      await tester.state<PlayerPageState>(find.byType(PlayerPage)).openFile();
      await tester.pumpAndSettle();
      expect(backend.opened.length, 1);
      expect(backend.value.status, PlaybackStatus.playing);
      await tester.tap(find.byTooltip('暂停'));
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.paused);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(backend.released, isTrue);
    },
  );

  testWidgets('command failure is visible and a subsequent open recovers', (
    tester,
  ) async {
    final backend = FakeBackend()..fail = true;
    await tester.pumpWidget(
      TestApp(
        home: PlayerPage(
          backend: backend,
          pickMedia: () async => LocalMedia(Uri.file('/demo.mp4'), 'demo.mp4'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.state<PlayerPageState>(find.byType(PlayerPage)).openFile();
    await tester.pumpAndSettle();
    expect(find.text('播放操作失败，请重新打开媒体文件。'), findsOneWidget);
    backend.fail = false;
    await tester.state<PlayerPageState>(find.byType(PlayerPage)).openFile();
    await tester.pumpAndSettle();
    expect(backend.value.status, PlaybackStatus.playing);
  });

  testWidgets('seek is submitted once after dragging finishes', (tester) async {
    final backend = FakeBackend();
    await tester.pumpWidget(
      TestApp(
        home: PlayerPage(
          backend: backend,
          pickMedia: () async => LocalMedia(Uri.file('/demo.mp4'), 'demo.mp4'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.state<PlayerPageState>(find.byType(PlayerPage)).openFile();
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
      TestApp(
        home: PlayerPage(
          backend: backend,
          pickMedia: () async => LocalMedia(Uri.file('/demo.mp4'), 'demo.mp4'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.state<PlayerPageState>(find.byType(PlayerPage)).openFile();
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
      expect(find.textContaining('剩余'), findsNothing);
      await tester.tap(find.byTooltip('快进 10 秒'));
      await tester.pumpAndSettle();
      expect(backend.seeks.last, const Duration(seconds: 60));
      backend.value = const PlayerSnapshot(status: PlaybackStatus.playing);
      await tester.pump();
      expect(
        tester
            .widget<ShadIconButton>(
              find.descendant(
                of: find.byTooltip('快进 10 秒'),
                matching: find.byType(ShadIconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('--:--'), findsOneWidget);
    },
  );

  /// A point on the video away from the centre controls.
  Offset videoSpot(WidgetTester tester, {double dx = 150, double dy = 300}) =>
      tester.getTopLeft(find.byKey(const Key('video-gestures'))) +
      Offset(dx, dy);

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
      // Selecting keeps the sheet open; tapping outside closes it.
      await tester.tapAt(const Offset(10, 300)); // outside the sheet
      await tester.pumpAndSettle();
      var gesture = await tester.startGesture(videoSpot(tester));
      await tester.pump(const Duration(milliseconds: 600));
      // From 1.5× the boost is 2×.
      expect(backend.speeds.last, 2);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(backend.speeds.last, 1.5);
      gesture = await tester.startGesture(videoSpot(tester));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(backend.speeds.last, 1.5);
    },
  );

  testWidgets('lock hides controls, blocks gestures and slides to unlock', (
    tester,
  ) async {
    final backend = FakeBackend();
    await openPlayer(tester, backend);
    await tester.tap(find.byTooltip('锁定控制'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('播放速度'), findsNothing);
    final count = backend.speeds.length;
    await tester.longPressAt(videoSpot(tester));
    await tester.pumpAndSettle();
    expect(backend.speeds.length, count);
    // A short drag springs back; a long one unlocks.
    await tester.drag(
      find.byKey(const Key('unlock-knob')),
      const Offset(40, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('暂停'), findsNothing);
    await tester.drag(
      find.byKey(const Key('unlock-knob')),
      const Offset(260, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('暂停'), findsOneWidget);
  });

  testWidgets('edge swipes set volume and brightness; tracks are wired', (
    tester,
  ) async {
    final backend = FakeBackend();
    await openPlayer(tester, backend);
    // Right half, upwards: volume.
    await tester.dragFrom(
      videoSpot(tester, dx: 650, dy: 400),
      const Offset(0, -150),
    );
    await tester.pump();
    expect(backend.volumes, isNotEmpty);
    expect(backend.volumes.last, greaterThan(0));
    await tester.pumpAndSettle();
    // Left half, downwards: brightness (dims the picture).
    await tester.dragFrom(
      videoSpot(tester, dx: 150, dy: 150),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<ColoredBox>(find.byKey(const Key('video-dimming'))).color.a,
      greaterThan(0),
    );
    // Audio tracks and subtitles open separately on phones.
    await tester.tap(find.byTooltip('音轨'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panel-audio')), findsOneWidget);
    expect(find.text('简体中文'), findsNothing);
    await tester.tap(find.text('English').first);
    await tester.pumpAndSettle();
    expect(backend.audioSelections, [7]);
    await tester.tap(find.byKey(const Key('panel-barrier')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('字幕'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panel-subtitles')), findsOneWidget);
    expect(find.text('中文'), findsNothing); // no audio tracks here
    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();
    expect(backend.subtitleSelections, [2]);
    await tester.tap(find.text('关闭字幕'));
    await tester.pumpAndSettle();
    expect(backend.subtitleSelections, [2, null]);
  });

  testWidgets('double taps seek on the sides (accumulating) and pause in the '
      'middle', (tester) async {
    final backend = FakeBackend();
    await openPlayer(tester, backend);
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.playing,
      position: Duration(seconds: 30),
      duration: Duration(seconds: 120),
      canSeek: true,
    );
    await tester.pump();
    Future<void> doubleTap(Offset at) async {
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 50));
    }

    final right = videoSpot(tester, dx: 720, dy: 150);
    await doubleTap(right);
    expect(backend.seeks.last, const Duration(seconds: 40));
    expect(find.byKey(const Key('double-tap-ripple')), findsOneWidget);
    expect(find.text('+10 秒'), findsOneWidget);
    await doubleTap(right);
    expect(find.text('+20 秒'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('double-tap-ripple')), findsNothing);
    await doubleTap(videoSpot(tester, dx: 400, dy: 150));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(backend.value.status, PlaybackStatus.paused);
  });

  testWidgets('horizontal drag previews the target and seeks once', (
    tester,
  ) async {
    final backend = FakeBackend();
    await openPlayer(tester, backend);
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.playing,
      position: Duration(seconds: 60),
      duration: Duration(minutes: 10),
      canSeek: true,
    );
    await tester.pump();
    final gesture = await tester.startGesture(
      videoSpot(tester, dx: 200, dy: 200),
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(360, 0));
    await tester.pump();
    expect(find.byKey(const Key('seek-feedback')), findsOneWidget);
    expect(backend.seeks, isEmpty);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('seek-feedback')), findsNothing);
    expect(backend.seeks, hasLength(1));
    // 400 px of an 800 px screen ≈ 45 s of the 90 s span.
    expect(backend.seeks.single.inSeconds, inInclusiveRange(100, 110));
  });

  testWidgets('more sheet: A-B loop, delays and media info', (tester) async {
    final backend = FakeBackend();
    await openPlayer(tester, backend);
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.playing,
      position: Duration(seconds: 10),
      duration: Duration(seconds: 60),
      canSeek: true,
      readSpeedMBps: 12.345,
    );
    await tester.pump();
    await tester.tap(find.byTooltip('更多播放设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A-B 循环'));
    await tester.pumpAndSettle();
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.playing,
      position: Duration(seconds: 20),
      duration: Duration(seconds: 60),
      canSeek: true,
    );
    await tester.pump();
    await tester.tap(find.text('A-B 循环'));
    await tester.pumpAndSettle();
    // Reaching B jumps back to A.
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.playing,
      position: Duration(seconds: 21),
      duration: Duration(seconds: 60),
      canSeek: true,
    );
    await tester.pumpAndSettle();
    expect(backend.seeks.last, const Duration(seconds: 10));
    expect(find.text('A-B'), findsOneWidget); // status chip

    await tester.tap(find.text('同步'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('audio-delay-plus')));
    await tester.tap(find.byKey(const Key('subtitle-delay-minus')));
    await tester.pumpAndSettle();
    expect(backend.audioDelays, [const Duration(milliseconds: 50)]);
    expect(backend.subtitleDelays, [const Duration(milliseconds: -50)]);
    expect(find.byKey(const Key('panel-sync')), findsOneWidget);

    await tester.tapAt(const Offset(10, 300)); // outside the sheet
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多播放设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('媒体信息'));
    await tester.pumpAndSettle();
    expect(find.text('h264'), findsOneWidget);
    expect(find.text('4.20 Mb/s'), findsOneWidget);
  });

  testWidgets('backgrounding restores speed and pauses active playback', (
    tester,
  ) async {
    final backend = FakeBackend();
    await openPlayer(tester, backend);
    final gesture = await tester.startGesture(videoSpot(tester));
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
      await tester.pumpAndSettle();
      await openPlayer(tester, FakeBackend());
      await tester.tap(find.byTooltip('更多播放设置'));
      await tester.pumpAndSettle();
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
        lessThanOrEqualTo(136),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byTooltip('暂停').hitTestable(), findsNothing);
      expect(
        tester.getSize(find.byKey(const Key('video-gestures'))),
        videoSize,
      );
      await tester.tapAt(videoSpot(tester));
      // A single tap waits out the double-tap window.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byTooltip('暂停').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('播放速度'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      // An open sheet keeps the controls up.
      expect(find.byTooltip('暂停').hitTestable(), findsNothing); // under barrier
      expect(find.text('1.5×'), findsOneWidget);
      await tester.tap(find.text('1.5×'));
      await tester.pumpAndSettle();
      expect(backend.speeds.last, 1.5);
      expect(find.text('1.5×'), findsWidgets);
    },
  );

  testWidgets('narrow layout reaches lock from the more sheet', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await openPlayer(tester, FakeBackend());
    await tester.tap(find.byTooltip('更多播放设置'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('panel-more')),
        matching: find.text('锁定'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('slide-to-unlock')), findsOneWidget);
  });

  testWidgets('control bar shows the read speed, measured or placeholder', (
    tester,
  ) async {
    final backend = FakeBackend();
    await openPlayer(tester, backend);
    final speed = find.byKey(const Key('playback-read-speed'));
    expect(speed, findsOneWidget);
    expect(tester.widget<Text>(speed).data, '-- MB/s');
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.playing,
      readSpeedMBps: 12.345,
      duration: Duration(seconds: 60),
      canSeek: true,
    );
    await tester.pump();
    expect(tester.widget<Text>(speed).data, '12.35 MB/s');
  });

  testWidgets('remote access streams carry a badge that follows the path', (
    tester,
  ) async {
    final backend = FakeBackend();
    await openPlayer(tester, backend);
    final badge = find.byKey(const Key('playback-remote-badge'));
    expect(badge, findsNothing);
    RemoteTransport.selectPath('remote-src', false);
    addTearDown(() => RemoteTransport.selectedPaths.remove('remote-src'));
    await tester
        .state<PlayerPageState>(find.byType(PlayerPage))
        .playSelection(
          SourceSelection(
            'movie.mkv',
            PlayableStream(Uri.parse('http://127.0.0.1:1/movie.mkv')),
            ref: const ResourceRef('remote-src', 'movie.mkv'),
          ),
        );
    await tester.pumpAndSettle();
    expect(badge, findsOneWidget);
    expect(find.text('远程'), findsOneWidget);
    // A reconnect that lands on the LAN clears it mid-playback.
    RemoteTransport.selectPath('remote-src', true);
    await tester.pumpAndSettle();
    expect(badge, findsNothing);
    // Another source moving does not touch this one.
    RemoteTransport.selectPath('other-src', false);
    addTearDown(() => RemoteTransport.selectedPaths.remove('other-src'));
    await tester.pumpAndSettle();
    expect(badge, findsNothing);
  });

  testWidgets('read speed lives in the statistics, measured or placeholder', (
    tester,
  ) async {
    final backend = FakeBackend();
    await openPlayer(tester, backend);
    await tester.tap(find.byTooltip('更多播放设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('媒体信息'));
    await tester.pumpAndSettle();
    // The control bar shows the same text; look only at the statistics.
    Finder stat(String text) => find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data == text &&
          w.key != const Key('playback-read-speed'),
    );
    expect(stat('-- MB/s'), findsOneWidget);
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.playing,
      readSpeedMBps: 12.345,
      duration: Duration(seconds: 60),
      canSeek: true,
    );
    await tester.pump();
    expect(stat('12.35 MB/s'), findsOneWidget);
    await tester.tapAt(const Offset(10, 300)); // outside the sheet
    await tester.pumpAndSettle();
  });

  testWidgets('portrait puts the picture on top and the controls below it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    await openPlayer(tester, backend);
    backend.value = const PlayerSnapshot(
      status: PlaybackStatus.playing,
      duration: Duration(seconds: 60),
      canSeek: true,
      videoSize: Size(1920, 1080),
    );
    await tester.pump();
    final video = tester.getRect(find.byType(PlayerVideoView));
    expect(video.top, 56);
    expect(video.height, closeTo(390 * 9 / 16, 0.5));
    final controls = tester.getRect(
      find.byKey(const Key('player-control-bar')),
    );
    expect(controls.top, greaterThanOrEqualTo(video.bottom));
    expect(find.text('demo.mp4'), findsOneWidget); // title below the picture
    expect(find.byTooltip('锁定控制'), findsOneWidget); // in the second row
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping up during a long press keeps the boost speed', (
    tester,
  ) async {
    final backend = FakeBackend();
    await openPlayer(tester, backend);
    final gesture = await tester.startGesture(videoSpot(tester));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('上滑锁定'), findsOneWidget);
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(backend.speeds.last, 2);
    expect(find.text('2×'), findsWidgets); // status chip and speed button
    await tester.pump(const Duration(seconds: 1));
  });
}
