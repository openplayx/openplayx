import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:openplayx/features/player/view/player_page.dart';
import 'package:openplayx_playback/playback.dart';

import '../../app_test_host.dart';
import 'player_page_test.dart' show FakeBackend;

class _VideoProbe extends StatefulWidget {
  const _VideoProbe();
  @override
  State<_VideoProbe> createState() => _VideoProbeState();
}

class _VideoProbeState extends State<_VideoProbe> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _Backend extends FakeBackend {
  int pauses = 0;
  @override
  Widget buildVideo() => const _VideoProbe();
  @override
  Future<void> pause() async {
    pauses++;
    await super.pause();
  }
}

void main() {
  const channel = MethodChannel('openplayx/picture_in_picture');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  Future<void> changed(bool active, {String method = 'changed'}) async {
    final done = Completer<void>();
    binding.channelBuffers.push(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, active),
      ),
      (_) => done.complete(),
    );
    await done.future;
  }

  Future<_Backend> open(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = _Backend();
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
    return backend;
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('unsupported platform and iOS engine hide the PiP action', (tester) async {
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    await open(tester);
    expect(find.byTooltip('画中画'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    messenger.setMockMethodCallHandler(channel, (_) async => true);
    await open(tester, platform: TargetPlatform.iOS);
    // A VLC fallback exposes no AVSampleBufferDisplayLayer output.
    expect(find.byTooltip('画中画'), findsNothing);
  });

  testWidgets(
    'PiP keeps one video view and preserves playback across background and restore',
    (tester) async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'isSupported') return true;
        if (call.method == 'enter') {
          await changed(true);
          return true;
        }
        if (call.method == 'exit') await changed(false);
        return null;
      });
      final backend = await open(tester);
      final original = tester.state(find.byType(_VideoProbe));
      await tester.tap(find.byTooltip('画中画'));
      await tester.pumpAndSettle();
      expect(calls, contains('enter'));
      expect(find.byKey(const Key('player-control-bar')), findsNothing);
      expect(tester.state(find.byType(_VideoProbe)), same(original));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(backend.pauses, 0);
      expect(backend.value.status, PlaybackStatus.playing);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await changed(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('player-control-bar')), findsOneWidget);
      expect(tester.state(find.byType(_VideoProbe)), same(original));
      expect(backend.opened, hasLength(1));
    },
  );

  testWidgets('dismissing PiP while backgrounded pauses audio', (tester) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      if (call.method == 'enter') {
        await changed(true);
        return true;
      }
      return null;
    });
    final backend = await open(tester);
    await tester.tap(find.byTooltip('画中画'));
    await tester.pumpAndSettle();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await changed(false);
    await tester.pump();
    expect(backend.pauses, greaterThan(0));
    expect(backend.value.status, PlaybackStatus.paused);
  });

  testWidgets('system restore before foreground lifecycle does not pause video', (tester) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      if (call.method == 'enter') { await changed(true); return true; }
      return null;
    });
    final backend = await open(tester);
    await tester.tap(find.byTooltip('画中画'));
    await tester.pumpAndSettle();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await changed(false, method: 'restoring');
    await tester.pump();
    expect(backend.pauses, 0);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(backend.pauses, 0);
    expect(find.byKey(const Key('player-control-bar')), findsOneWidget);
  });

  testWidgets(
    'failed PiP entry restores controls and normal background pause',
    (tester) async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'isSupported',
      );
      final backend = await open(tester);
      await tester.tap(find.byTooltip('画中画'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('player-control-bar')), findsOneWidget);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(backend.pauses, greaterThan(0));
    },
  );

  testWidgets(
    'background transition before native acknowledgement keeps playing',
    (tester) async {
      final entered = Completer<bool>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isSupported') return true;
        if (call.method == 'enter') {
          binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          return entered.future;
        }
        return null;
      });
      final backend = await open(tester);
      await tester.tap(find.byTooltip('画中画'));
      await tester.pumpAndSettle();
      expect(backend.pauses, 0);
      await changed(true);
      entered.complete(true);
      await tester.pump();
      expect(backend.value.status, PlaybackStatus.playing);
    },
  );

  testWidgets(
    'paused playback can enter PiP and restore using its enabled button',
    (tester) async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isSupported') return true;
        if (call.method == 'enter') {
          await changed(true);
          return true;
        }
        if (call.method == 'exit') await changed(false);
        return null;
      });
      final backend = await open(tester, platform: TargetPlatform.windows);
      await backend.pause();
      await tester.pump();
      await tester.tap(find.byTooltip('画中画'));
      await tester.pumpAndSettle();
      expect(backend.value.status, PlaybackStatus.paused);
      await tester.tap(find.byTooltip('退出画中画'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('画中画'), findsOneWidget);
      expect(backend.value.status, PlaybackStatus.paused);
    },
  );

  testWidgets(
    'desktop mini player restores with Escape without reopening media',
    (tester) async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'isSupported') return true;
        if (call.method == 'enter') {
          await changed(true);
          return true;
        }
        if (call.method == 'exit') await changed(false);
        return null;
      });
      final backend = await open(tester, platform: TargetPlatform.windows);
      final original = tester.state(find.byType(_VideoProbe));
      await tester.tap(find.byTooltip('画中画'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('退出画中画'), findsOneWidget);
      expect(tester.state(find.byType(_VideoProbe)), same(original));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(calls, contains('exit'));
      expect(find.byTooltip('画中画'), findsOneWidget);
      expect(backend.opened, hasLength(1));
    },
  );

  testWidgets(
    'Android arms PiP auto-enter only while a video is playing',
    (tester) async {
      final autoEnter = <bool>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isSupported') return true;
        if (call.method == 'setAutoEnter') {
          autoEnter.add((call.arguments as Map)['enabled'] == true);
          return true;
        }
        return null;
      });
      final backend = await open(tester);
      expect(autoEnter, isNotEmpty);
      expect(autoEnter.last, isTrue);
      await backend.pause();
      await tester.pumpAndSettle();
      expect(autoEnter.last, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(autoEnter.last, isFalse);
    },
  );

  testWidgets('iOS never arms PiP auto-enter', (tester) async {
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return call.method == 'isSupported';
    });
    await open(tester, platform: TargetPlatform.iOS);
    expect(methods, isNot(contains('setAutoEnter')));
  });
}
