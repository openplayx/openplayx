import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/features/player/controller/subtitle_controller.dart';
import 'package:openplayx/features/player/model/subtitle_choice.dart';
import 'package:openplayx/features/player/model/subtitle_state.dart';
import 'package:openplayx/capabilities/speech/recognized_subtitles.dart';
import 'package:openplayx_playback/playback.dart';

import 'player_page_test.dart' show FakeBackend;

/// Player that accepts subtitle files like libVLC: an added file becomes a
/// new track (20, 21, …), reported only while [reportFiles] is true.
class _Backend extends FakeBackend {
  final files = <Uri>[];
  bool reportFiles = true;

  /// Holds [addExternalSubtitle] until completed.
  Completer<void>? gate;

  @override
  bool get supportsExternalSubtitles => true;

  @override
  Future<void> addExternalSubtitle(Uri file) async {
    await gate?.future;
    files.add(file);
  }

  @override
  Future<List<PlayerSubtitleTrack>> getSubtitleTracks() async => [
    ...await super.getSubtitleTracks(),
    if (reportFiles)
      for (var i = 0; i < files.length; i++)
        PlayerSubtitleTrack(id: 20 + i, name: 'Track ${20 + i}'),
  ];
}

class _Repository implements RecognizedSubtitleRepository {
  _Repository(this.saved);
  List<RecognizedSubtitle> saved;
  final controller = StreamController<void>.broadcast();
  @override
  Future<List<RecognizedSubtitle>> list(ResourceRef ref) async => saved;
  @override
  Stream<void> get changes => controller.stream;
}

class _Choices implements SubtitleChoiceStore {
  SubtitleChoice? choice;
  @override
  SubtitleChoice? loadSubtitleChoice() => choice;
  @override
  void saveSubtitleChoice(SubtitleChoice choice) => this.choice = choice;
}

RecognizedSubtitle _saved(String id) => RecognizedSubtitle(
  bindingId: id,
  path: '/subs/$id.srt',
  format: 'srt',
  language: 'en',
  partial: false,
  rangeStartMs: 0,
  rangeEndMs: 60000,
  backend: 'embedded',
  modelId: 'whisper',
  created: DateTime(2026),
);

void main() {
  late _Backend backend;
  late _Repository repository;
  late SubtitleController subtitles;
  late _Choices choices;

  setUp(() {
    backend = _Backend();
    repository = _Repository([_saved('b1')]);
    choices = _Choices();
    subtitles = SubtitleController(
      backend: backend,
      attempt: (action) async {
        try {
          await action();
          return true;
        } catch (_) {
          return false;
        }
      },
      currentRef: () => const ResourceRef('@local', '/a.mkv'),
      repository: repository,
      choices: choices,
    );
  });
  tearDown(() => subtitles.dispose());

  SubtitleState state() => subtitles.state;
  String recognized(String id) => SubtitleOption.recognizedKey(id);

  test('groups the options by source and marks nothing by default', () async {
    await subtitles.refresh();
    expect(state().embedded.map((o) => o.playerId), [2, 5]);
    expect(state().external, isEmpty);
    expect(state().recognized.single.key, recognized('b1'));
    expect(state().recognized.single.playerId, isNull); // not loaded yet
    expect(state().selection, isA<SubtitleDefault>());
    expect(state().options.where(state().isSelected), isEmpty);
  });

  test('a recognised subtitle is loaded once; choosing it again only '
      'switches', () async {
    await subtitles.refresh();
    expect(await subtitles.choose(recognized('b1')), isTrue);
    expect(backend.files, [Uri.file('/subs/b1.srt')]);
    expect(state().option(recognized('b1'))!.playerId, 20);
    // The loaded copy is not listed again as an embedded track.
    expect(state().embedded.map((o) => o.playerId), [2, 5]);
    expect(state().isSelected(state().option(recognized('b1'))!), isTrue);

    await subtitles.choose(SubtitleOption.embeddedKey(2));
    await subtitles.choose(recognized('b1'));
    expect(backend.files, hasLength(1));
    expect(backend.subtitleSelections, [2, 20]);
  });

  test('a track reported late is matched on a later listing, never listed '
      'as embedded', () async {
    backend.reportFiles = false;
    final file = Uri.file('/subs/movie.srt');
    expect(await subtitles.addFile(file), isTrue);
    final key = SubtitleOption.externalKey(file);
    // The player shows an added file at once, track id or not.
    expect(state().selection, isA<SubtitleChosen>());
    expect(state().option(key)!.loading, isTrue);

    backend.reportFiles = true;
    await subtitles.refresh();
    expect(state().option(key)!.playerId, 20);
    expect(state().option(key)!.loading, isFalse);
    expect(state().external.single.name, 'movie.srt');
    expect(state().embedded.map((o) => o.playerId), [2, 5]);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('adding the same file again re-selects it', () async {
    final file = Uri.file('/subs/movie.srt');
    await subtitles.addFile(file);
    await subtitles.turnOff();
    await subtitles.addFile(file);
    expect(backend.files, hasLength(1));
    expect(backend.subtitleSelections, [null, 20]);
  });

  test('requests reach the player in order; a superseded queued request '
      'is skipped', () async {
    await subtitles.refresh();
    backend.gate = Completer();
    final load = subtitles.choose(recognized('b1'));
    final second = subtitles.choose(SubtitleOption.embeddedKey(2));
    final third = subtitles.choose(SubtitleOption.embeddedKey(5));
    backend.gate!.complete();
    expect(await load, isTrue);
    expect(await second, isFalse);
    expect(await third, isTrue);
    expect(backend.subtitleSelections, [5]);
    expect(
      state().selected?.key,
      SubtitleOption.embeddedKey(5),
      reason: 'the last request wins, in the player and in the state',
    );
  });

  test('cycling covers off and every group; on/off returns to the last '
      'choice', () async {
    await subtitles.refresh();
    final next = state().cycleTarget(1) as SubtitleChosen;
    expect(next.key, SubtitleOption.embeddedKey(2));
    expect(state().cycleTarget(-1), isA<SubtitleOff>());

    await subtitles.choose(recognized('b1'));
    expect(state().cycleTarget(1), isA<SubtitleOff>()); // wraps
    await subtitles.apply(state().toggleTarget!);
    expect(state().isOff, isTrue);
    final back = state().toggleTarget as SubtitleChosen;
    expect(back.key, recognized('b1'));
  });

  test('saved subtitles follow repository changes', () async {
    await subtitles.reloadSaved();
    expect(state().recognized, hasLength(1));
    repository.saved = [_saved('b2'), _saved('b1')];
    repository.controller.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(state().recognized.map((o) => o.key), [
      recognized('b2'),
      recognized('b1'),
    ]);
  });

  test('a new media drops late results of the previous one', () async {
    await subtitles.refresh();
    backend.gate = Completer();
    final load = subtitles.choose(recognized('b1'));
    await Future<void>.delayed(Duration.zero);
    subtitles.reset();
    backend.gate!.complete();
    expect(await load, isFalse);
    expect(state().options, isEmpty);
    expect(state().selection, isA<SubtitleDefault>());
  });

  group('remembered choice', () {
    test('every choice is remembered in a form found again later', () async {
      await subtitles.refresh();
      await subtitles.choose(SubtitleOption.embeddedKey(5));
      expect(choices.choice!.toJson(), {
        'kind': 'embedded',
        'player_id': 5,
        'name': 'English',
        'language': 'en',
      });
      await subtitles.choose(recognized('b1'));
      expect(choices.choice!.toJson(), {
        'kind': 'recognized',
        'binding_id': 'b1',
      });
      await subtitles.turnOff();
      expect(choices.choice, isA<OffChoice>());
      final decoded = SubtitleChoice.decode(
        const RecognizedChoice('b1').encode(),
      );
      expect((decoded as RecognizedChoice).bindingId, 'b1');
      expect(SubtitleChoice.decode('{"kind":"future"}'), isNull);
      expect(SubtitleChoice.decode('not json'), isNull);
    });

    test('an embedded track is found by id and name, else by a unique name '
        'and language', () async {
      choices.choice = const EmbeddedChoice(
        playerId: 5,
        name: 'English',
        language: 'en',
      );
      expect(await subtitles.restore(), isTrue);
      expect(backend.subtitleSelections, [5]);

      subtitles.reset();
      backend.subtitleSelections.clear();
      choices.choice = const EmbeddedChoice(
        playerId: 9, // ids differ in this session
        name: 'English',
        language: 'en',
      );
      expect(await subtitles.restore(), isTrue);
      expect(backend.subtitleSelections, [5]);

      subtitles.reset();
      backend.subtitleSelections.clear();
      choices.choice = const EmbeddedChoice(playerId: 9, name: 'Deutsch');
      expect(await subtitles.restore(), isFalse);
      expect(backend.subtitleSelections, isEmpty);
    });

    test('recognised, off and existing files come back; missing files do '
        'not', () async {
      choices.choice = const RecognizedChoice('b1');
      expect(await subtitles.restore(), isTrue);
      expect(backend.files, [Uri.file('/subs/b1.srt')]);

      subtitles.reset();
      choices.choice = const OffChoice();
      expect(await subtitles.restore(), isTrue);
      expect(subtitles.state.isOff, isTrue);

      subtitles.reset();
      choices.choice = ExternalChoice(Uri.file('/missing/movie.srt'));
      expect(await subtitles.restore(), isFalse);

      final dir = Directory.systemTemp.createTempSync('subs');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/movie.srt')..writeAsStringSync('x');
      subtitles.reset();
      choices.choice = ExternalChoice(file.uri);
      expect(await subtitles.restore(), isTrue);
      expect(backend.files.last, file.uri);
    });

    test(
      'a choice the user already made wins over the remembered one',
      () async {
        await subtitles.refresh();
        await subtitles.choose(SubtitleOption.embeddedKey(2));
        choices.choice = const OffChoice();
        expect(await subtitles.restore(), isFalse);
        expect(backend.subtitleSelections, [2]);
      },
    );
  });
}
