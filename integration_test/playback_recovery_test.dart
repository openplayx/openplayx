import 'dart:io';

// Match the application's Material widgets during Flutter's migration.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx_media/openplayx_media.dart';

import 'package:openplayx/features/player/adapters/player_engines.dart';

import '../test/app_test_host.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // The engine draws frames on its own schedule and the waits below are real
  // time: tester.pump waits for a frame, which a window in the background
  // does not get for many seconds, while the media keeps playing.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  for (final scenario in [
    'switch',
    'corrupt',
    'http-recovery',
    'no-audio-http',
  ]) {
    testWidgets('native playback regression: $scenario', (tester) async {
      final directory = await Directory.systemTemp.createTemp('opx-recovery-');
      final backend = createPlayerBackend();
      HttpServer? server;
      addTearDown(() async {
        backend.dispose();
        await server?.close(force: true);
        await directory.delete(recursive: true);
      });
      Future<File> fixture(String name) async {
        final data = await rootBundle.load('test/fixtures/$name');
        return File('${directory.path}/$name').writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      }

      // Distinct player states, for failure messages.
      final trace = <String>[];
      void record() {
        final v = backend.value;
        final line =
            '${v.status.name} @${v.position.inSeconds}s/${v.duration.inMilliseconds}ms '
            '${v.videoSize?.width.toInt()}x${v.videoSize?.height.toInt()}';
        if (trace.isEmpty || trace.last != line) trace.add(line);
      }

      backend.addListener(record);
      addTearDown(() => backend.removeListener(record));

      Future<void> waitFor(bool Function() condition, String stage) async {
        final deadline = DateTime.now().add(const Duration(seconds: 25));
        while (DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          if (condition()) return;
        }
        fail(
          '$scenario / $stage: ${backend.value.status}, '
          '${backend.value.position}, ${backend.value.duration}, '
          'video ${backend.value.videoSize}, ${engineOf(backend)}; '
          'states: ${trace.skip(trace.length > 12 ? trace.length - 12 : 0).join(' > ')}',
        );
      }

      // Frames keep coming while a media opens: the engine router creates
      // the engine inside open(), and libmpv's video setup waits for frames.
      Future<void> open(Uri uri) async {
        var done = false;
        Object? error;
        final opening = backend
            .open(uri)
            .then(
              (_) => done = true,
              onError: (Object e) {
                error = e;
                done = true;
              },
            );
        final deadline = DateTime.now().add(const Duration(seconds: 25));
        while (!done && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        if (!done) fail('$scenario: opening $uri did not complete');
        await opening;
        if (error != null) throw error!;
      }

      // Record the rejection state before retrying, but assert it after recovery
      // so an incorrect error event cannot prevent the recovery path being tested.
      Future<PlaybackStatus> rejectionState() async {
        final deadline = DateTime.now().add(const Duration(seconds: 25));
        while (DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          final status = backend.value.status;
          if (status == PlaybackStatus.error ||
              status == PlaybackStatus.ended) {
            return status;
          }
        }
        return backend.value.status;
      }

      Future<void> playing(int seconds) => waitFor(
        () =>
            backend.value.status == PlaybackStatus.playing &&
            backend.value.position > const Duration(milliseconds: 1200) &&
            (backend.value.duration.inMilliseconds - seconds * 1000).abs() <
                700 &&
            backend.value.videoSize == const Size(160, 90),
        'playing $seconds second fixture',
      );

      await tester.pumpWidget(
        TestApp(
          home: Scaffold(body: PlayerVideoView(backend: backend)),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final first = await fixture('test_video.mp4');
      final second = await fixture('test_video_short.mp4');
      await open(first.uri);
      await playing(12);

      if (scenario == 'switch' || scenario == 'corrupt') {
        PlaybackStatus? rejectedStatus;
        String? rejectedEngine;
        if (scenario == 'corrupt') {
          final bad = await File('${directory.path}/corrupt.mp4')
              .writeAsBytes(List.filled(256, 7));
          await open(bad.uri);
          rejectedStatus = await rejectionState();
          rejectedEngine = engineOf(backend);
        }
        await open(second.uri);
        await playing(5);
        // Wait for B's real end event: stale A events must not restore its duration.
        await waitFor(
          () => backend.value.status == PlaybackStatus.ended,
          'second media ends',
        );
        expect(
          backend.value.duration.inMilliseconds,
          inInclusiveRange(4300, 5700),
        );
        await open(first.uri);
        await playing(12);
        if (scenario == 'corrupt') {
          expect(
            rejectedStatus,
            PlaybackStatus.error,
            reason:
                'Recovery succeeded, but corrupt input must report an error '
                '($rejectedEngine)',
          );
        }
      } else {
        final bytes =
            await (scenario == 'no-audio-http'
                    ? await fixture('test_video_no_audio.mp4')
                    : first)
                .readAsBytes();
        var available = scenario != 'http-recovery';
        var failures = 0;
        var successes = 0;
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          final response = request.response;
          if (!available) {
            failures++;
            response.statusCode = HttpStatus.serviceUnavailable;
            await response.close();
            return;
          }
          successes++;
          response.headers.contentType = ContentType('video', 'mp4');
          response.headers.set('Accept-Ranges', 'bytes');
          var start = 0;
          var end = bytes.length - 1;
          final range = request.headers.value('Range');
          if (range != null) {
            final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
            if (match == null) {
              response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
              response.headers.set('Content-Range', 'bytes */${bytes.length}');
              await response.close();
              return;
            }
            start = int.parse(match[1]!);
            end = match[2]!.isEmpty ? end : int.parse(match[2]!);
            if (end >= bytes.length) end = bytes.length - 1;
            if (start > end) {
              response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
              response.headers.set('Content-Range', 'bytes */${bytes.length}');
              await response.close();
              return;
            }
            response.statusCode = HttpStatus.partialContent;
            response.headers.set(
              'Content-Range',
              'bytes $start-$end/${bytes.length}',
            );
          }
          response.contentLength = end - start + 1;
          try {
            if (request.method != 'HEAD') {
              response.add(bytes.sublist(start, end + 1));
            }
            await response.close();
          } on IOException {
            // VLC may close a Range request when it seeks or changes media.
          }
        });
        final uri = Uri.parse('http://127.0.0.1:${server.port}/video.mp4');
        await open(uri);
        PlaybackStatus? rejectedStatus;
        String? rejectedEngine;
        if (scenario == 'http-recovery') {
          await waitFor(() => failures > 0, 'HTTP failure requested');
          rejectedStatus = await rejectionState();
          rejectedEngine = engineOf(backend);
          expect(failures, greaterThan(0));
          available = true;
          await open(uri);
        }
        await playing(12);
        expect(successes, greaterThan(0));
        if (scenario == 'http-recovery') {
          expect(
            rejectedStatus,
            PlaybackStatus.error,
            reason:
                'Retry succeeded, but HTTP 503 must report an error '
                '($rejectedEngine)',
          );
        }
        if (scenario == 'no-audio-http') {
          expect(
            (await backend.getAudioTracks()).where((t) => t.id >= 0),
            isEmpty,
          );
          await waitFor(
            () => backend.value.status == PlaybackStatus.ended,
            'audio-free HTTP video reaches end',
          );
          expect(backend.value.position.inSeconds, greaterThanOrEqualTo(10));
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}

/// The engine behind a routed player, for failure messages.
String engineOf(PlayerBackend backend) => backend is RoutedPlayerBackend
    ? 'engine ${backend.engine?.name}${backend.fellBack ? ' (fallback)' : ''}'
    : backend.runtimeType.toString();
