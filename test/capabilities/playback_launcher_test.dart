import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/playback/playback_launcher.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';

import '../services/plugins/plugin_manager_test.dart' show FakeSources;

void main() {
  final launcher = PlaybackLauncher(FakeSources());

  test('a local file plays as is; a missing one is reported', () async {
    final dir = Directory.systemTemp.createTempSync('launcher');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/film.mp4')..writeAsStringSync('x');
    final selection = await launcher.select(
      ResourceRef('@local', file.path),
      'film.mp4',
    );
    expect(selection!.stream.uri, Uri.file(file.path));
    expect(selection.ref!.id, file.path);
    expect(
      () => launcher.open(ResourceRef('@local', '${dir.path}/gone.mp4')),
      throwsA(isA<MediaUnavailable>()),
    );
  });

  test('a selection nobody wants any more is not returned', () async {
    final dir = Directory.systemTemp.createTempSync('launcher');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/film.mp4')..writeAsStringSync('x');
    final selection = await launcher.select(
      ResourceRef('@local', file.path),
      'film.mp4',
      wanted: () => false,
    );
    expect(selection, isNull);
  });
}
