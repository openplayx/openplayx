import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:openplayx_playback/playback.dart';

import '../../../core/capabilities/source_capability.dart';
import '../../../capabilities/speech/recognized_subtitles.dart';
import '../model/subtitle_choice.dart';
import '../model/subtitle_state.dart';
import 'player_attempt.dart';

/// Remembers the chosen subtitle of the current resource across sessions.
abstract class SubtitleChoiceStore {
  SubtitleChoice? loadSubtitleChoice();
  void saveSubtitleChoice(SubtitleChoice choice);
}

/// A file added to the player for the current media.
class _Attachment {
  _Attachment(this.key, this.file, this.source);
  final String key;
  final Uri file;
  final SubtitleSource source;

  /// The player's track for the file, once it reported one.
  int? playerId;
}

/// Subtitles of the current media: the player's tracks, files the user
/// added and saved recognised subtitles, as one list of options. Panels,
/// menus, keys and the assistant all go through it.
///
/// The player cannot report which track it shows, so every command that
/// changes it goes through here, one at a time and in order: the last
/// request is also the last command the player gets, and the selection
/// follows what the player does (an added file is shown at once). The
/// player reports an added file's track only later; it is matched to the
/// file when a new track id shows up in a later listing, in the order the
/// files were added. Tracks are listed on demand only (listing can stall
/// VLCKit), never polled in the background.
class SubtitleController extends ChangeNotifier {
  SubtitleController({
    required this.backend,
    required this.attempt,
    required this.currentRef,
    this.repository,
    this.choices,
  });

  final PlayerBackend backend;
  final PlayerAttempt attempt;

  /// Resource being played, for its saved recognised subtitles.
  final ResourceRef? Function() currentRef;

  /// Saved recognised subtitles; null lists none.
  final RecognizedSubtitleRepository? repository;

  /// Where the choice is remembered; null remembers nothing.
  final SubtitleChoiceStore? choices;

  SubtitleState _state = const SubtitleState();
  SubtitleState get state => _state;
  bool _disposed = false;

  // Raw inputs the options are built from.
  List<PlayerSubtitleTrack> _tracks = const [];
  List<RecognizedSubtitle> _saved = const [];
  final _seen = <int>{};
  final _attachments = <_Attachment>[];

  /// Bumped for every new media; late results of an older one are dropped.
  int _media = 0;

  /// Bumped for every selection request; a queued request that is no longer
  /// the latest is skipped.
  int _request = 0;

  /// Completes when the queued commands are done; null while idle, so no
  /// stale future outlives the commands.
  Future<void>? _queue;
  StreamSubscription<void>? _changes;
  bool _loadingSaved = false, _savedDirty = false;

  // ---- State ---------------------------------------------------------------

  void _publish({SubtitleSelection? selection, String? lastChosen}) {
    if (_disposed) return;
    final attachedTo = {
      for (final a in _attachments)
        if (a.playerId != null) a.playerId!: a,
    };
    String fileName(Uri file) =>
        file.pathSegments.where((s) => s.isNotEmpty).lastOrNull ??
        file.toString();
    SubtitleOption attachment(_Attachment a, {String? name}) => SubtitleOption(
      key: a.key,
      source: a.source,
      name: name ?? fileName(a.file),
      playerId: a.playerId,
      loading: a.playerId == null,
    );
    final recognizedKeys = {
      for (final s in _saved) SubtitleOption.recognizedKey(s.bindingId),
    };
    _state = _state.copyWith(
      options: [
        for (final t in _tracks)
          if (!attachedTo.containsKey(t.id))
            SubtitleOption(
              key: SubtitleOption.embeddedKey(t.id),
              source: const EmbeddedSubtitle(),
              name: t.name,
              language: t.language,
              playerId: t.id,
            ),
        for (final a in _attachments)
          if (a.source is ExternalSubtitle) attachment(a),
        for (final s in _saved)
          if (_attachment(SubtitleOption.recognizedKey(s.bindingId))
              case final a?)
            attachment(a, name: s.language ?? '')
          else
            SubtitleOption(
              key: SubtitleOption.recognizedKey(s.bindingId),
              source: RecognizedSubtitleSource(s),
              name: s.language ?? '',
            ),
        // Loaded recognised subtitles whose saved record went away stay
        // choosable while they are in the player.
        for (final a in _attachments)
          if (a.source is RecognizedSubtitleSource &&
              !recognizedKeys.contains(a.key))
            attachment(a),
      ],
      selection: selection,
      lastChosen: lastChosen,
    );
    notifyListeners();
  }

  _Attachment? _attachment(String key) =>
      _attachments.where((a) => a.key == key).firstOrNull;

  /// Takes in a track listing: new track ids belong to added files still
  /// waiting for theirs (in order), the rest are the media's own.
  void _absorb(List<PlayerSubtitleTrack> tracks) {
    for (final t in tracks) {
      if (!_seen.add(t.id)) continue;
      _attachments.where((a) => a.playerId == null).firstOrNull?.playerId =
          t.id;
    }
    _tracks = tracks;
  }

  bool _stale(int media) => _disposed || media != _media;

  // ---- Listing ---------------------------------------------------------------

  /// Lists the player's tracks and the saved recognised subtitles; throws
  /// when the player cannot list its tracks.
  Future<void> refresh() async {
    final media = _media;
    final tracks = await backend.getSubtitleTracks();
    final saved = await savedSubtitles();
    if (_stale(media)) return;
    _absorb(tracks);
    _saved = saved;
    _publish();
  }

  /// Saved recognised subtitles of the current resource, newest first.
  Future<List<RecognizedSubtitle>> savedSubtitles() async {
    final ref = currentRef();
    if (ref == null ||
        repository == null ||
        !backend.supportsExternalSubtitles) {
      return const [];
    }
    try {
      return await repository!.list(ref);
    } catch (_) {
      return const [];
    }
  }

  /// Re-reads the saved recognised subtitles (no player query) and follows
  /// later changes; call once the resource is known.
  Future<void> reloadSaved() async {
    _changes ??= repository?.changes.listen((_) => reloadSaved());
    if (_loadingSaved) {
      _savedDirty = true;
      return;
    }
    _loadingSaved = true;
    try {
      do {
        _savedDirty = false;
        final media = _media;
        final saved = await savedSubtitles();
        if (_stale(media)) return;
        _saved = saved;
        _publish();
      } while (_savedDirty && !_disposed);
    } finally {
      _loadingSaved = false;
    }
  }

  // ---- Choosing ----------------------------------------------------------------

  /// Runs player subtitle commands one at a time, in request order.
  Future<T> _serial<T>(Future<T> Function() command) {
    final previous = _queue;
    final result = previous == null
        ? command()
        : previous.then((_) => command());
    late final Future<void> tail;
    tail = result.then<void>((_) {}, onError: (_) {}).whenComplete(() {
      if (identical(_queue, tail)) _queue = null;
    });
    _queue = tail;
    return result;
  }

  /// Runs a selection request unless a newer one or a new media came first.
  Future<bool> _enqueue(Future<bool> Function() command) {
    final request = ++_request, media = _media;
    return _serial(() async {
      if (request != _request || _stale(media)) return false;
      return command();
    });
  }

  /// Applies [target]: off, or an option by key.
  Future<bool> apply(SubtitleSelection target) => switch (target) {
    SubtitleOff() => turnOff(),
    SubtitleChosen(:final key) => choose(key),
    SubtitleDefault() => Future.value(false),
  };

  Future<bool> turnOff() => _enqueue(() async {
    final media = _media;
    if (!await attempt(backend.disableSubtitle) || _stale(media)) return false;
    _publish(selection: const SubtitleOff());
    choices?.saveSubtitleChoice(const OffChoice());
    return true;
  });

  /// Shows the option [key]: switches to its track, loading a recognised
  /// subtitle into the player the first time.
  Future<bool> choose(String key) => _enqueue(() async {
    final media = _media;
    final option = _state.option(key);
    if (option == null) return false;
    final attached = _attachment(key);
    bool ok;
    if (option.playerId != null) {
      ok = await attempt(() => backend.setSubtitleTrack(option.playerId!));
    } else if (attached != null) {
      // Added before; the player has not reported its track yet.
      ok = await attempt(() async {
        await _awaitTrack(attached, media);
        final id = attached.playerId;
        if (id == null) throw StateError('Subtitle track not reported yet');
        await backend.setSubtitleTrack(id);
      });
    } else if (option.source case RecognizedSubtitleSource(:final saved)) {
      ok = await _attach(
        _Attachment(key, Uri.file(saved.path), option.source),
        media,
      );
    } else {
      return false;
    }
    if (!ok || _stale(media)) return false;
    _chosen(key);
    return true;
  });

  void _chosen(String key) {
    _publish(selection: SubtitleChosen(key), lastChosen: key);
    if (_state.option(key) case final option?) {
      choices?.saveSubtitleChoice(SubtitleChoice.of(option));
    }
  }

  /// Shows a saved recognised subtitle (also one not listed yet).
  Future<bool> chooseRecognized(RecognizedSubtitle subtitle) {
    final key = SubtitleOption.recognizedKey(subtitle.bindingId);
    if (_state.option(key) == null) {
      _saved = [subtitle, ..._saved];
      _publish();
    }
    return choose(key);
  }

  /// Adds a subtitle file and shows it; a file added before is shown again.
  Future<bool> addFile(Uri file) {
    final key = SubtitleOption.externalKey(file);
    if (_attachment(key) != null) return choose(key);
    return _enqueue(() async {
      final media = _media;
      final ok = await _attach(
        _Attachment(key, file, ExternalSubtitle(file)),
        media,
      );
      if (!ok || _stale(media)) return false;
      _chosen(key);
      return true;
    });
  }

  /// Applies the subtitle remembered for this resource, unless the user
  /// chose one already. Lists the player's tracks once when the choice is
  /// one of them; call when the media plays and the resource is known.
  Future<bool> restore() async {
    final choice = choices?.loadSubtitleChoice();
    if (choice == null || _state.selection is! SubtitleDefault) return false;
    final media = _media;
    switch (choice) {
      case OffChoice():
        return turnOff();
      case ExternalChoice(:final file):
        if (file.scheme == 'file' && !File(file.toFilePath()).existsSync()) {
          return false;
        }
        return addFile(file);
      case EmbeddedChoice() || RecognizedChoice():
        try {
          await refresh();
        } catch (_) {
          return false;
        }
        if (_stale(media) || _state.selection is! SubtitleDefault) {
          return false;
        }
        final option = switch (choice) {
          EmbeddedChoice() => choice.match(_state.embedded),
          RecognizedChoice(:final bindingId) => _state.option(
            SubtitleOption.recognizedKey(bindingId),
          ),
          _ => null,
        };
        return option == null ? false : choose(option.key);
    }
  }

  /// Adds [attachment]'s file to the player, which shows it at once, and
  /// waits briefly for its track.
  Future<bool> _attach(_Attachment attachment, int media) => attempt(() async {
    // Known tracks first, so the file's track is the only new one.
    _absorb(await backend.getSubtitleTracks());
    if (_stale(media)) return;
    _attachments.add(attachment);
    _publish();
    try {
      await backend.addExternalSubtitle(attachment.file);
    } catch (_) {
      _attachments.remove(attachment);
      _publish();
      rethrow;
    }
    await _awaitTrack(attachment, media);
  });

  /// Lists tracks until [attachment]'s shows up, for about 1.5 s. A later
  /// listing still matches it if the player reports it after that.
  Future<void> _awaitTrack(_Attachment attachment, int media) async {
    for (var i = 0; i < 15 && !_stale(media); i++) {
      _absorb(await backend.getSubtitleTracks());
      if (_stale(media)) return;
      _publish();
      if (attachment.playerId != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<bool> setDelay(Duration delay) async {
    if (!backend.supportsDelays) return false;
    if (!await attempt(() => backend.setSubtitleDelay(delay)) || _disposed) {
      return false;
    }
    _state = _state.copyWith(delay: delay);
    notifyListeners();
    return true;
  }

  /// Forgets everything about the previous media.
  void reset() {
    _media++;
    _request++;
    _tracks = const [];
    _saved = const [];
    _seen.clear();
    _attachments.clear();
    if (_disposed) return;
    _state = const SubtitleState();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_changes?.cancel());
    super.dispose();
  }
}
