import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/features/player/controller/player_controller.dart';
import 'package:openplayx_playback/playback.dart';

import 'player_page_test.dart' show FakeBackend;

void main() {
  late FakeBackend backend;
  late PlayerController controller;
  setUp(() {
    backend = FakeBackend();
    controller = PlayerController(
      backend: backend,
      sources: SourceManager(),
      attempt: (action) async {
        await action();
        return true;
      },
      canControl: () => true,
      onSaveFailed: () {},
      onTitle: (_) {},
      onSleepFinished: () {},
      onCommandFailed: () {},
      onStatusChanged: () {},
      onBoostEnded: () {},
    );
  });
  tearDown(() async {
    controller.dispose();
    await controller.releaseStream();
    backend.dispose();
  });
  test(
    'native playback error stops, retries once, then releases old stream',
    () async {
      final order = <String>[];
      final next = PlayableStream(
        Uri.parse('http://localhost/remux.ts'),
        release: () async {
          order.add('release remux');
        },
      );
      final direct = PlayableStream(
        Uri.parse('http://localhost/direct.mp4'),
        fallback: () async {
          order.add('retry');
          expect(backend.stops, 1);
          return next;
        },
        release: () async {
          order.add('release direct');
        },
      );
      controller.beginMedia('Test');
      await controller.openSelection(SourceSelection('Test', direct));
      backend.value = const PlayerSnapshot(status: PlaybackStatus.error);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(backend.opened.map((u) => u.path), ['/direct.mp4', '/remux.ts']);
      expect(order, ['release direct', 'retry']);
      backend.value = const PlayerSnapshot(status: PlaybackStatus.error);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(backend.opened, hasLength(2));
      await controller.releaseStream();
      expect(order.last, 'release remux');
    },
  );
  test(
    'cancelled pending fallback is released without opening or replacing media',
    () async {
      final ready = Completer<PlayableStream>();
      var released = 0;
      final direct = PlayableStream(
        Uri.parse('http://localhost/direct.mp4'),
        fallback: () => ready.future,
      );
      controller.beginMedia('Test');
      await controller.openSelection(SourceSelection('Test', direct));
      backend.value = const PlayerSnapshot(status: PlaybackStatus.error);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await controller.releaseStream();
      ready.complete(
        PlayableStream(
          Uri.parse('http://localhost/late.ts'),
          release: () async {
            released++;
          },
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(backend.opened, hasLength(1));
      expect(released, 1);
    },
  );
}
