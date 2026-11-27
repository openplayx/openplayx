import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx_ffmpeg/openplayx_ffmpeg.dart';
import 'package:openplayx_media/openplayx_media.dart';

/// Verifies inside the real app bundle that the in-process FFmpeg bridge
/// links and loads (no process, no PATH lookup) and can probe and snapshot.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('bundled FFmpeg bridge and libVLC decode in one process', (
    tester,
  ) async {
    final processor = MediaProcessor();
    expect(processor.available, isTrue);
    final caps = await processor.capabilities();
    expect(caps.available, isTrue);
    expect(caps.encoders, contains('mjpeg'));

    final dir = await Directory.systemTemp.createTemp('opx-ffmpeg-it');
    addTearDown(() => dir.delete(recursive: true));
    final data = await rootBundle.load('test/fixtures/test_video.mp4');
    final input = File('${dir.path}/clip.mp4')
      ..writeAsBytesSync(data.buffer.asUint8List());

    // Exercise both users of shared FFmpeg, including processing after VLC
    // initializes the library's process-wide state. Force software decoding
    // so VideoToolbox cannot bypass the avcodec integration being tested.
    final backend = LibVlcBackend(
      extraOptions: const [
        '--codec=avcodec',
        '--avcodec-hw=none',
        '--aout=dummy',
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    });
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 320,
          height: 240,
          child: PlayerVideoView(backend: backend),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await backend.open(Uri.file(input.path));
    final watch = Stopwatch()..start();
    var decodedVideo = 0;
    while (watch.elapsed < const Duration(seconds: 10) && decodedVideo == 0) {
      await tester.pump(const Duration(milliseconds: 100));
      decodedVideo = (await backend.getStats())?.decodedVideo ?? 0;
    }
    expect(decodedVideo, greaterThan(0), reason: 'libVLC software decoding');

    final probe = await processor.probe(input.path);
    expect(probe.primaryVideo, isNotNull);
    final plan = MediaPlanner.plan(
      MediaPreset.imagePreview,
      probe,
      caps,
      PlanRequest(time: Duration(microseconds: probe.durationUs ~/ 2)),
    );
    final result = await processor
        .submit(plan, input: input.path, output: '${dir.path}/frame.jpg')
        .done;
    expect(result.succeeded, isTrue, reason: '${result.error}');
    expect(File(result.outputPath!).lengthSync(), greaterThan(0));
    processor.dispose();
  });
}
