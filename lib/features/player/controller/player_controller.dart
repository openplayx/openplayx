import 'dart:async';

import '../../../data/analytics/analytics_service.dart';
import '../../../data/analytics/playback_analytics.dart';

import 'package:flutter/foundation.dart';
import 'package:openplayx_playback/playback.dart';

import '../../../data/diagnostics/diagnostics_bootstrap.dart';
import '../../../core/capabilities/source_capability.dart';
import '../../../data/files/local_media_picker.dart';
import '../../../data/remote_access/remote_transport.dart';
import '../../../data/sources/source_config.dart';
import '../../../capabilities/sources/source_manager.dart';
import '../../../capabilities/library/library_service.dart';
import '../../../capabilities/speech/recognized_subtitles.dart';
import '../../../capabilities/speech/subtitle_generation_service.dart';
import '../model/player_state.dart';
import 'audio_track_controller.dart';
import 'media_info_controller.dart';
import 'playback_history.dart';
import 'playback_tools_controller.dart';
import 'player_attempt.dart';
import 'subtitle_controller.dart';
import 'subtitle_alignment_controller.dart';

/// Entry point of the player logic: holds the backend and the media being
/// played, opens and stops media, and owns the feature controllers, which
/// it resets whenever the media changes. The view drives the UI around it
/// (controls, panels, dialogs) through the callbacks.
class PlayerController extends ChangeNotifier {
  PlayerController({
    required this.backend,
    required this.sources,
    required PlayerAttempt attempt,
    required bool Function() canControl,
    required void Function() onSaveFailed,
    required void Function(String title) onTitle,
    required void Function() onSleepFinished,
    required this.onCommandFailed,
    required this.onStatusChanged,
    required this.onBoostEnded,
    LibraryService? library,
    RecognizedSubtitleRepository? recognizedSubtitles,
  }) {
    history = PlaybackHistory(
      backend: backend,
      attempt: attempt,
      library: library,
      onSaveFailed: onSaveFailed,
      onTitle: onTitle,
      onTracked: () {
        onPlayback();
        unawaited(subtitles.reloadSaved());
        _tracked = true;
        _restoreSubtitle();
      },
    );
    tools = PlaybackToolsController(
      backend: backend,
      attempt: attempt,
      command: command,
      canControl: canControl,
      resumeAt: history.resumeAt,
      onSleepFinished: onSleepFinished,
    );
    audio = AudioTrackController(backend: backend, attempt: attempt);
    subtitles = SubtitleController(
      backend: backend,
      attempt: attempt,
      currentRef: () => history.session.ref,
      choices: history,
      repository:
          recognizedSubtitles ??
          LibraryRecognizedSubtitles(
            () async => (await history.ensureLibrary()).db,
            changes: () => SubtitleGenerationService.current?.changes,
          ),
    );
    alignment = SubtitleAlignmentController(
      subtitles: subtitles,
      duration: () => backend.value.duration,
    );
    info = MediaInfoController(backend: backend);
    backend.addListener(onPlayback);
  }

  final PlayerBackend backend;
  final SourceManager sources;

  /// A playback command failed; the controls should show the error.
  final void Function() onCommandFailed;

  /// The playback status changed (playing, paused, ended…).
  final void Function() onStatusChanged;

  /// The long-press boost ended because playback stopped playing.
  final void Function() onBoostEnded;

  late final PlaybackHistory history;
  late final PlaybackToolsController tools;
  late final AudioTrackController audio;
  late final SubtitleController subtitles;
  late final SubtitleAlignmentController alignment;
  late final MediaInfoController info;

  PlayerState _state = const PlayerState();
  PlayerState get state => _state;
  bool _disposed = false;
  PlayableStream? _stream;
  Future<void>? _streamRecovery;
  int _mediaEpoch = 0;

  /// Source of the current stream, watched for LAN / remote access moves.
  String? _remoteSource;
  StreamSubscription<String>? _pathChanges;

  /// A non-local path for the current source means remote access through a
  /// relay (server traffic).
  void _refreshRemote() {
    if (_disposed) return;
    _pathChanges ??= RemoteTransport.pathChanges.listen((id) {
      if (id == _remoteSource) _refreshRemote();
    });
    final path = _remoteSource == null
        ? null
        : RemoteTransport.selectedPaths[_remoteSource];
    final remote = path != null && !path.$1;
    if (remote != _state.remote) _set(_state.copyWith(remote: remote));
  }

  PlaybackStatus _lastStatus = PlaybackStatus.idle;

  // The remembered subtitle is applied once per media, when it plays and
  // its library record is known.
  bool _tracked = false, _played = false, _restored = false;
  late final _analytics = PlaybackAnalytics(
    emit: (event, properties) {
      unawaited(AnalyticsService.instance.capture(event, properties));
    },
  );

  void _restoreSubtitle() {
    if (_restored || !_tracked || !_played || _disposed) return;
    _restored = true;
    unawaited(subtitles.restore());
  }

  /// True once the owning view is gone.
  bool get disposed => _disposed;

  void _set(PlayerState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  /// Whether the media accepts commands (the view adds its own lock).
  bool get canControlMedia =>
      _state.hasMedia &&
      !_state.busy &&
      !_state.closing &&
      !_state.background &&
      _state.error == null &&
      switch (backend.value.status) {
        PlaybackStatus.playing ||
        PlaybackStatus.paused ||
        PlaybackStatus.ended => true,
        _ => false,
      };

  /// Runs a playback command; a failure is reported and shown as an error.
  Future<void> command(Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stack) {
      unawaited(reportDiagnostic(error, DiagnosticRole.player, stack));
      debugPrint('Playback command failed: $error\n$stack');
      if (!_disposed) {
        _set(_state.copyWith(error: () => PlayerError.playbackCommand));
        onCommandFailed();
      }
    }
  }

  void setBusy(bool busy) => _set(_state.copyWith(busy: busy));
  void setClosing(bool closing) => _set(_state.copyWith(closing: closing));

  /// The picked file could not be opened.
  void failOpen() => _set(_state.copyWith(error: () => PlayerError.openFile));

  /// Phones pause in the background and stay paused until they return.
  void setBackground(bool background) {
    _state = _state.copyWith(background: background);
    if (background && _state.hasMedia) unawaited(command(backend.pause));
  }

  void _resetFeatures() {
    tools.reset();
    audio.reset();
    alignment.reset();
    subtitles.reset();
    info.reset();
  }

  /// Switches to a new media named [name]: saves and forgets the previous
  /// one, clears the error and every per-media state.
  void beginMedia(String name) {
    _mediaEpoch++;
    _tracked = _played = _restored = false;
    _remoteSource = null;
    _analytics.begin();
    history.finish();
    _resetFeatures();
    _set(_state.copyWith(name: () => name, error: () => null, remote: false));
  }

  /// Opens a picked local file (after [beginMedia]).
  Future<void> openLocal(LocalMedia media) async {
    await command(() async {
      await backend.open(media.uri);
      await backend.setSpeed(tools.state.speed);
      await _stream?.release();
      _stream = null;
    });
    if (_state.error == null && media.uri.scheme == 'file') {
      unawaited(history.trackLocal(media));
    }
    if (_state.background && !_disposed) await command(backend.pause);
  }

  /// Opens a stream picked from a source (after [beginMedia]); the player
  /// holds the stream until the next media or stop.
  Future<void> openSelection(SourceSelection selection) async {
    final previous = _stream;
    _stream = selection.stream;
    await command(() async {
      try {
        await backend.open(selection.stream.uri);
      } catch (_) {
        if (selection.stream.fallback == null) rethrow;
        await _recoverStream(selection.stream);
      }
      if (backend.value.status == PlaybackStatus.error &&
          selection.stream.fallback != null) {
        await _recoverStream(selection.stream);
      }
      await backend.setSpeed(tools.state.speed);
    });
    await previous?.release();
    final ref = selection.ref;
    _remoteSource = ref?.instanceId;
    _refreshRemote();
    if (_state.error == null && ref != null) {
      String? localPath;
      final config = sources.configs
          .where((c) => c.id == ref.instanceId)
          .firstOrNull;
      if (config?.kind == SourceKind.local || ref.instanceId == '@local') {
        localPath = ref.id;
      }
      unawaited(
        history.track(
          ref,
          selection.name,
          localPath: localPath,
          entry: selection.entry,
        ),
      );
    }
    if (_state.background && !_disposed) await command(backend.pause);
  }

  /// Stops the backend and saves the history; [restoreDisplay] runs in
  /// between (screen orientation). Throws when the backend fails.
  Future<void> stopMedia({
    required Future<void> Function() restoreDisplay,
  }) async {
    _mediaEpoch++;
    history.checkpoint(force: true);
    _analytics.finish();
    await backend.stop();
    await restoreDisplay();
    history.finish();
    await releaseStream();
  }

  /// Forgets the stopped media.
  void endMedia() {
    _analytics.finish();
    tools.cancelSleep();
    _resetFeatures();
    _set(_state.copyWith(name: () => null, error: () => null));
  }

  Future<void> releaseStream() async {
    _mediaEpoch++;
    final stream = _stream;
    _stream = null;
    await stream?.release();
  }

  /// Follows every playback change: resume, progress, seeks, loops, end of
  /// the media, boost and background pause.
  void onPlayback() {
    final snapshot = backend.value;
    final stream = _stream;
    if (snapshot.status == PlaybackStatus.error &&
        stream?.fallback != null &&
        _streamRecovery == null &&
        !_disposed &&
        !_state.closing) {
      unawaited(command(() => _recoverStream(stream!)));
    }
    _analytics.update(snapshot);
    if (history.onPlayback(snapshot)) return;
    tools.onPlayback(snapshot);
    if (_lastStatus != snapshot.status) {
      final previous = _lastStatus;
      _lastStatus = snapshot.status;
      if (snapshot.status == PlaybackStatus.ended &&
          previous != PlaybackStatus.ended) {
        tools.onEnded(hasMedia: _state.hasMedia);
      }
      if (!_disposed) onStatusChanged();
    }
    if (!_played && snapshot.status == PlaybackStatus.playing) {
      _played = true;
      _restoreSubtitle();
    }
    if (tools.state.boosting && snapshot.status != PlaybackStatus.playing) {
      if (tools.endBoost()) onBoostEnded();
    }
    if (_state.background && snapshot.status == PlaybackStatus.playing) {
      unawaited(command(backend.pause));
    }
  }

  Future<void> _recoverStream(PlayableStream stream) {
    final pending = _streamRecovery;
    if (pending != null) return pending;
    final epoch = _mediaEpoch;
    // Defer until the backend has finished notifying listeners.
    final recovery = Future<void>(() async {
      if (_disposed || epoch != _mediaEpoch || _stream != stream) return;
      await backend.stop();
      final next = await stream.retry(releaseCurrent: true);
      if (next == null) return;
      if (_disposed || epoch != _mediaEpoch || _stream != stream) {
        await next.release();
        return;
      }
      await stream.release();
      if (_disposed || epoch != _mediaEpoch || _stream != stream) {
        await next.release();
        return;
      }
      _stream = next;
      await backend.open(next.uri);
      await backend.setSpeed(tools.state.speed);
      if (_state.background && !_disposed) await backend.pause();
    });
    _streamRecovery = recovery;
    return recovery.whenComplete(() {
      if (_streamRecovery == recovery) _streamRecovery = null;
    });
  }

  /// Saves the last position and stops listening; the stream and the
  /// backend are released by their owner afterwards.
  @override
  void dispose() {
    _mediaEpoch++;
    _analytics.finish();
    history.dispose();
    _disposed = true;
    unawaited(_pathChanges?.cancel());
    backend.removeListener(onPlayback);
    tools.dispose();
    audio.dispose();
    alignment.dispose();
    subtitles.dispose();
    info.dispose();
    super.dispose();
  }
}
