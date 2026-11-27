import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/features/player/controller/subtitle_alignment_controller.dart';
import 'package:openplayx/features/player/controller/subtitle_controller.dart';
import 'package:openplayx_playback/playback.dart';

import '../../capabilities/subtitles/subtitle_alignment_test.dart' show fixture;
import 'player_page_test.dart' show FakeBackend;

class Backend extends FakeBackend {
  final files = <Uri>[];
  @override
  bool get supportsExternalSubtitles => true;
  @override
  Future<void> addExternalSubtitle(Uri file) async {
    files.add(file);
  }

  @override
  Future<List<PlayerSubtitleTrack>> getSubtitleTracks() async => [
    ...await super.getSubtitleTracks(),
    for (var i = 0; i < files.length; i++)
      PlayerSubtitleTrack(id: 20 + i, name: 'external $i'),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Backend backend;
  late SubtitleController subtitles;
  late SubtitleAlignmentController c;
  late File source;
  late File ref;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('opx-align-test-');
    backend = Backend();
    subtitles = SubtitleController(
      backend: backend,
      attempt: (fn) async {
        try {
          await fn();
          return true;
        } catch (_) {
          return false;
        }
      },
      currentRef: () => null,
    );
    c = SubtitleAlignmentController(
      subtitles: subtitles,
      duration: () => const Duration(seconds: 500),
      outputDirectory: () async => root,
    );
    source = await File('${root.path}/source.srt').writeAsString(fixture());
    ref = await File('${root.path}/reference.srt')
        .writeAsString(fixture(offset: 2500));
    await subtitles.addFile(source.uri);
    c.setReference(ref.uri);
  });
  tearDown(() async {
    c.dispose();
    subtitles.dispose();
    backend.dispose();
    await root.delete(recursive: true);
  });
  test('analysis never changes playback; explicit preview, acceptance and undo preserve original', () async {
    await subtitles.setDelay(const Duration(milliseconds: 500));
    await c.start();
    expect(c.result?.safe, isTrue);
    expect(backend.files, [source.uri]);
    expect(await c.useCandidate(), isTrue);
    expect(c.previewing, isTrue);
    expect(c.applied, isFalse);
    expect(subtitles.state.delay, Duration.zero);
    expect(backend.files.last, isNot(source.uri));
    expect(await source.readAsString(), fixture());
    expect(await c.useCandidate(accept: true), isTrue);
    expect(c.applied, isTrue);
    expect(c.history.length, 1);
    expect(await c.restore(), isTrue);
    expect(subtitles.state.selected?.key, 'file:${source.uri}');
    expect(subtitles.state.delay, const Duration(milliseconds: 500));
    expect(c.applied, isFalse);
  });
  test('manual delay undo survives the view lifetime and respects external changes', () async {
    await c.setManualDelay(const Duration(milliseconds: 250));
    await c.setManualDelay(const Duration(milliseconds: 500));
    expect(c.canRestoreManual, isTrue);
    expect(await c.restoreManual(), isTrue);
    expect(subtitles.state.delay, Duration.zero);
    await c.setManualDelay(const Duration(milliseconds: 250));
    await subtitles.setDelay(const Duration(seconds: 1));
    expect(c.canRestoreManual, isFalse);
  });
  test('manual selection after a preview releases its lock without changing user choice', () async {
    await c.start();
    await c.useCandidate();
    await subtitles.turnOff();
    expect(c.previewing, isFalse);
    expect(c.canUndo, isFalse);
    expect(subtitles.state.isOff, isTrue);
    c.setReference(ref.uri);
    expect(c.phase, AlignmentPhase.idle);
  });
  test('a modified source file cannot use an old candidate', () async {
    await c.start();
    await source.writeAsString(fixture(offset: 1000));
    expect(await c.useCandidate(accept: true), isFalse);
    expect(c.error, 'source_changed');
    expect(backend.files, [source.uri]);
  });
  test('changing subtitle after analysis disables apply', () async {
    await c.start();
    await subtitles.turnOff();
    expect(c.canApply, isFalse);
    expect(await c.useCandidate(accept: true), isFalse);
    expect(backend.files.length, 1);
  });
  test(
    'cancel invalidates an in-flight read and does not publish a result',
    () async {
      final task = c.start();
      c.cancel();
      await task;
      expect(c.phase, AlignmentPhase.idle);
      expect(c.result, isNull);
      expect(backend.files.length, 1);
    },
  );
  test('new media invalidates analysis and all undo state', () async {
    final task = c.start();
    c.reset();
    subtitles.reset();
    await task;
    expect(c.result, isNull);
    expect(c.reference, isNull);
    expect(c.canUndo, isFalse);
    expect(c.canApply, isFalse);
  });
  test(
    'invalid and oversized files are reported without mutating subtitles',
    () async {
      await ref.writeAsString('broken');
      await c.start();
      expect(c.phase, AlignmentPhase.failed);
      expect(backend.files.length, 1);
      await ref.writeAsString('x' * (4 * 1024 * 1024 + 1));
      await c.start();
      expect(c.error, 'too_large');
      expect(backend.files.length, 1);
    },
  );
  test('no boundary evidence produces review and cannot preview', () async {
    final unknown = SubtitleAlignmentController(
      subtitles: subtitles,
      duration: () => Duration.zero,
      outputDirectory: () async => root,
    );
    unknown.setReference(ref.uri);
    await unknown.start();
    expect(unknown.phase, AlignmentPhase.review);
    expect(await unknown.useCandidate(), isFalse);
    unknown.dispose();
  });
}
