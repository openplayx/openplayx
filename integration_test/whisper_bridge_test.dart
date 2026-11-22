import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx/capabilities/speech/asr_model_store.dart';
import 'package:openplayx_whisper/openplayx_whisper.dart';

import 'support/live_services.dart';

/// Verifies inside the real app bundle that the in-process whisper.cpp
/// bridge links and loads (not the stub, no process) and validates inputs.
/// Recognition uses a pinned tiny model and known synthetic English speech.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('bundled whisper bridge is the real engine', (tester) async {
    final engine = WhisperEngine();
    addTearDown(engine.dispose);
    final info = engine.info();
    expect(info.available, isTrue);
    expect(info.engineVersion, startsWith(WhisperEngine.pinnedVersion));
    final dir = await Directory.systemTemp.createTemp('opx-whisper-it');
    addTearDown(() => dir.delete(recursive: true));
    final fake = File('${dir.path}/model.bin')
      ..writeAsBytesSync(List.filled(1024, 7));
    await expectLater(
      engine.openModel(fake.path),
      throwsA(
        isA<AsrException>().having(
          (e) => e.code,
          'code',
          AsrErrorCode.modelUnavailable,
        ),
      ),
    );
  });

  testWidgets('bundled whisper recognises speech with bounded timestamps', (
    tester,
  ) async {
    final dir = await Directory.systemTemp.createTemp('opx-whisper-speech-');
    final engine = WhisperEngine();
    addTearDown(() async {
      engine.dispose();
      await dir.delete(recursive: true);
    });
    expect(engine.info().available, isTrue);
    await tester.runAsync(() async {
      final spec = asrModelSpec('whisper-tiny-multilingual')!;
      final hostModel = File('$asrModelDirectory/${spec.file}');
      String modelPath;
      if (asrModelDirectory.isNotEmpty && await hostModel.exists()) {
        expect(await AsrModelStore.sha256File(hostModel), spec.sha256);
        modelPath = hostModel.path;
      } else {
        // Device sandboxes cannot read ASR_MODEL_DIR on the build host.
        // Download the pinned model into test-owned storage and verify it.
        final store = AsrModelStore(
          Future.value(Directory('${dir.path}/models')),
        );
        final download = store.download(spec.id);
        try {
          await download.done.timeout(const Duration(minutes: 5));
        } finally {
          download.cancel();
          // Ensure a timed-out download has stopped before teardown deletes it.
          await download.done.catchError((Object _) {});
        }
        modelPath = (await store.path(spec.id))!;
      }
      final data = await rootBundle.load('test/fixtures/asr_en.wav');
      final input = await File('${dir.path}/speech.wav').writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final model = await engine.openModel(modelPath);
      // Which accelerator the device actually got (MTL0 / Vulkan0 / CPU).
      // ignore: avoid_print
      print('whisper backend: ${model.backend} ${model.device}');
      try {
        final job = engine.transcribe(
          model,
          AsrRequest(input: input.path, language: 'en'),
        );
        AsrJobResult result;
        try {
          result = await job.done.timeout(const Duration(minutes: 2));
        } finally {
          job.cancel();
          await job.done;
        }
        expect(result.succeeded, isTrue, reason: '${result.error}');
        final transcript = result.transcript!;
        expect(transcript.language, 'en');
        expect(transcript.audioMs, inInclusiveRange(5600, 5700));
        final segments = transcript.windows.expand((w) => w.segments).toList();
        expect(segments, isNotEmpty);
        expect(
          segments.map((s) => s.text).join(' ').toLowerCase(),
          contains('quick brown fox'),
        );
        var previousStart = 0;
        for (final segment in segments) {
          expect(segment.startMs, greaterThanOrEqualTo(previousStart));
          expect(segment.endMs, greaterThan(segment.startMs));
          expect(segment.endMs, lessThanOrEqualTo(transcript.audioMs + 200));
          previousStart = segment.startMs;
        }
      } finally {
        model.close();
      }
    });
  }, timeout: const Timeout(Duration(minutes: 8)));
}
