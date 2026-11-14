import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx_whisper/openplayx_whisper.dart';

/// Verifies inside the real app bundle that the in-process whisper.cpp
/// bridge links and loads (not the stub, no process) and validates inputs.
/// No model ships with the app, so recognition itself is covered by the
/// package and service tests.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('bundled whisper bridge is the real engine', (tester) async {
    final engine = WhisperEngine();
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
    engine.dispose();
  });
}
