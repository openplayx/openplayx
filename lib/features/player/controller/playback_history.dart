import 'dart:async';
import 'dart:io';

import 'package:openplayx_playback/playback.dart';

import '../../../core/capabilities/source_capability.dart';
import '../../../data/files/local_media_picker.dart';
import '../../../capabilities/library/library_service.dart';
import '../model/playback_session.dart';
import '../model/subtitle_choice.dart';
import 'player_attempt.dart';
import 'subtitle_controller.dart';

/// Registers what plays in the library, resumes from the last position and
/// saves watch progress and the chosen subtitle.
class PlaybackHistory implements SubtitleChoiceStore {
  PlaybackHistory({
    required this.backend,
    required this.attempt,
    required this.onSaveFailed,
    required this.onTitle,
    required this.onTracked,
    LibraryService? library,
  }) : _library = library,
       _ownsLibrary = library == null;

  final PlayerBackend backend;
  final PlayerAttempt attempt;

  /// The library could not be opened or written.
  final void Function() onSaveFailed;

  /// The library knows a display title for the media.
  final void Function(String title) onTitle;

  /// Tracking started; playback state should be re-evaluated (resume).
  final void Function() onTracked;

  LibraryService? _library;
  final bool _ownsLibrary;
  Future<LibraryService>? _openingLibrary;
  bool _disposed = false;

  PlaybackSession _session = const PlaybackSession();
  PlaybackSession get session => _session;
  Duration? _resume;
  bool _resuming = false;
  DateTime? _lastCheckpoint;

  /// Bumped for every new media; late results of an older one are dropped.
  int _generation = 0;
  int get generation => _generation;

  Future<LibraryService> ensureLibrary() async {
    if (_library != null) return _library!;
    try {
      final service = await (_openingLibrary ??= LibraryService.open());
      if (_disposed) {
        service.close();
        throw StateError('Player is closed');
      }
      return _library = service;
    } catch (_) {
      _openingLibrary = null;
      rethrow;
    }
  }

  /// Continue from [target] once the media plays (also used to seek after
  /// the end, which the player ignores until it restarts).
  void resumeAt(Duration target) => _resume = target;

  void checkpoint({bool force = false}) {
    final value = backend.value;
    final resource = _session.resourceId, session = _session.sessionId;
    if (resource == null ||
        session == null ||
        _resume != null ||
        _resuming ||
        ![
          PlaybackStatus.playing,
          PlaybackStatus.paused,
          PlaybackStatus.ended,
        ].contains(value.status)) {
      return;
    }
    final now = DateTime.now();
    if (!force &&
        _lastCheckpoint != null &&
        now.difference(_lastCheckpoint!).inSeconds < 5) {
      return;
    }
    _lastCheckpoint = now;
    try {
      _library?.saveProgress(
        resource,
        session,
        value.position,
        value.duration,
        completed: value.status == PlaybackStatus.ended,
      );
    } catch (_) {
      _session = _session.detached();
      if (!_disposed) onSaveFailed();
    }
  }

  @override
  SubtitleChoice? loadSubtitleChoice() {
    final resource = _session.resourceId;
    if (resource == null) return null;
    try {
      final text = _library?.subtitleChoice(resource);
      return text == null ? null : SubtitleChoice.decode(text);
    } catch (_) {
      return null;
    }
  }

  @override
  void saveSubtitleChoice(SubtitleChoice choice) {
    final resource = _session.resourceId;
    if (resource == null) return;
    try {
      _library?.saveSubtitleChoice(resource, choice.encode());
    } catch (_) {
      // Remembering the subtitle is a convenience; playback goes on.
    }
  }

  /// Saves the final position and forgets the current media.
  void finish() {
    checkpoint(force: true);
    _generation++;
    _session = const PlaybackSession();
    _resuming = false;
    _resume = null;
    _lastCheckpoint = null;
  }

  Future<void> track(
    ResourceRef ref,
    String name, {
    String? localPath,
    int? generation,
    SourceEntry? entry,
  }) async {
    generation ??= _generation;
    _session = PlaybackSession(ref: ref);
    try {
      final service = await ensureLibrary();
      if (_disposed || generation != _generation) return;
      final media = service.register(
        entry ?? SourceEntry(ref, name, isFolder: false),
        localPath: localPath,
      );
      final resource =
          service.resourceFor(ref) ?? service.resources(media).first;
      final id = resource['id'] as String;
      final checkpoint = service.checkpoint(id);
      _session = _session.copyWith(resourceId: id);
      final title = service.metadata.fields(media)['title']?.toString().trim();
      if (!_disposed && title != null && title.isNotEmpty) onTitle(title);
      if (checkpoint != null &&
          checkpoint['completed'] == 0 &&
          (checkpoint['position'] as int) > 0) {
        _resume = Duration(milliseconds: checkpoint['position'] as int);
      }
      _session = _session.copyWith(sessionId: service.beginSession(id));
      onTracked();
    } catch (_) {
      _openingLibrary = null;
      // A storage error must not prevent direct playback.
      if (!_disposed) onSaveFailed();
    }
  }

  Future<void> trackLocal(LocalMedia media) async {
    final generation = _generation;
    var path = media.uri.toFilePath();
    try {
      path = await File(path).resolveSymbolicLinks();
    } catch (_) {}
    if (_disposed || generation != _generation) return;
    await track(
      ResourceRef('@local', path),
      media.name,
      localPath: path,
      generation: generation,
    );
  }

  /// Follows a playback change: seeks to the resume position once the media
  /// can seek (returns true then), otherwise saves progress.
  bool onPlayback(PlayerSnapshot snapshot) {
    if (_resume != null &&
        snapshot.canSeek &&
        snapshot.duration > Duration.zero &&
        [
          PlaybackStatus.playing,
          PlaybackStatus.paused,
        ].contains(snapshot.status)) {
      final target = _resume!;
      _resume = null;
      _resuming = true;
      // Only this exact resource's timeline is eligible for continuation.
      final generation = _generation;
      unawaited(
        attempt(
          () =>
              backend.seek(target < snapshot.duration ? target : Duration.zero),
        ).whenComplete(() {
          if (generation == _generation) {
            _resuming = false;
            checkpoint(force: true);
          }
        }),
      );
      return true;
    }
    checkpoint(
      force:
          snapshot.status == PlaybackStatus.paused ||
          snapshot.status == PlaybackStatus.ended,
    );
    return false;
  }

  /// Saves the last position; closes the library if this player opened it.
  void dispose() {
    finish();
    _disposed = true;
    if (_ownsLibrary) _library?.close();
  }
}
