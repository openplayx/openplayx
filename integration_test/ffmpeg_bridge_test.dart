import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx_ffmpeg/openplayx_ffmpeg.dart';

/// Verifies inside the real app bundle that the in-process FFmpeg bridge
/// links and loads (no process, no PATH lookup) and can probe and snapshot.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('bundled FFmpeg bridge probes and snapshots in process', (
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
