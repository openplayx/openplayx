import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:openplayx_playback/playback.dart';
import 'package:path_provider/path_provider.dart';

import '../model/playback_tools_state.dart';
import 'player_attempt.dart';

/// Speed and long-press boost, seeking, A-B loop, sleep timer,
/// repeat, volume and snapshots.
class PlaybackToolsController extends ChangeNotifier {
  PlaybackToolsController({
    required this.backend,
    required this.attempt,
    required this.command,
    required this.canControl,
    required this.resumeAt,
    required this.onSleepFinished,
  });

  final PlayerBackend backend;
  final PlayerAttempt attempt;
  final PlayerCommand command;

  /// Whether the player accepts user commands right now.
  final bool Function() canControl;

  /// Continue from a position once the media plays again.
  final void Function(Duration target) resumeAt;

  /// The sleep timer paused playback.
  final void Function() onSleepFinished;

  PlaybackToolsState _state = const PlaybackToolsState();
  PlaybackToolsState get state => _state;
  bool _disposed = false;
  Timer? _sleepTimer;
  int _volumeBeforeMute = 100;

  void _set(PlaybackToolsState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  // ---- Speed ---------------------------------------------------------------

  Future<void> _speedCommands = Future.value();

  /// Completes once earlier native rate changes are done.
  Future<void> get speedCommands => _speedCommands;

  // Serialize native rate changes so a slow press cannot overtake its release.
  Future<void> _applySpeed(double speed) {
    return _speedCommands = _speedCommands.then((_) async {
      if (!_disposed) await attempt(() => backend.setSpeed(speed));
    });
  }

  /// Sets the persistent speed; returns it once applied, null otherwise.
  Future<double?> setSpeed(double speed) async {
    speed = clampSpeed(speed);
    await _speedCommands;
    if (_disposed || !canControl()) return null;
    if (await attempt(() => backend.setSpeed(speed)) && !_disposed) {
      _set(_state.copyWith(speed: speed));
      return speed;
    }
    return null;
  }

  /// Records a speed the player was set to elsewhere (the assistant).
  void speedChanged(double speed) => _set(_state.copyWith(speed: speed));

  /// Starts the long-press boost; false when the player cannot boost now.
  bool startBoost() {
    if (!canControl() || backend.value.status != PlaybackStatus.playing) {
      return false;
    }
    _set(_state.copyWith(boosting: true));
    unawaited(_applySpeed(boostSpeed(_state.speed)));
    return true;
  }

  /// Keeps the boost speed as the persistent speed (design MG10); returns
  /// it, or null without a boost.
  double? lockBoost() {
    if (!_state.boosting) return null;
    final speed = boostSpeed(_state.speed);
    _set(_state.copyWith(boosting: false, speed: speed));
    unawaited(_applySpeed(speed));
    return speed;
  }

  /// Ends the boost; false when none was running.
  bool endBoost() {
    if (!_state.boosting) return false;
    _set(_state.copyWith(boosting: false));
    unawaited(_applySpeed(_state.speed));
    return true;
  }

  // ---- Seeking -------------------------------------------------------------

  /// Target of the last seek until the player reports it. Native position
  /// events lag a seek, so repeated jumps and the seek bar build on this
  /// instead of the stale position.
  Duration? _pendingSeek;
  DateTime? _pendingSeekAt;

  /// Start position and every target of the current chain of quick seeks;
  /// reports near any of them belong to the chain.
  final _pendingSeekChain = <Duration>[];

  /// Position to show and to build relative seeks on.
  Duration get position {
    final pending = _pendingSeek;
    if (pending != null && !_pendingSeekExpired) return pending;
    return backend.value.position;
  }

  /// A pending target expires after 2 s of playback without confirmation;
  /// while paused VLCKit reports no new time, so it stays until playback.
  bool get _pendingSeekExpired =>
      _pendingSeekAt == null ||
      (backend.value.status != PlaybackStatus.paused &&
          DateTime.now().difference(_pendingSeekAt!) >
              const Duration(seconds: 2));

  /// Absolute seek through the shared path (keys, bar, gestures, menus).
  Future<void> seekAbsolute(Duration target) async {
    final max = backend.value.duration;
    if (target.isNegative) target = Duration.zero;
    if (max > Duration.zero && target > max) target = max;
    if (backend.value.status == PlaybackStatus.ended) {
      // VLC ignores seeks after the end: restart, then continue from the
      // target once the media plays again (same path as resuming history).
      resumeAt(target);
      _pendingSeek = target;
      _pendingSeekChain
        ..clear()
        ..add(backend.value.position)
        ..add(target);
      _pendingSeekAt = DateTime.now();
      await command(backend.play);
      return;
    }
    if (_pendingSeek == null) {
      _pendingSeekChain
        ..clear()
        ..add(backend.value.position);
    }
    _pendingSeekChain.add(target);
    _pendingSeek = target;
    _pendingSeekAt = DateTime.now();
    return command(() => backend.seek(target));
  }

  /// Play/pause toggled: a seek made while paused is confirmed only once
  /// playback resumes.
  void playToggled() {
    if (_pendingSeek != null) _pendingSeekAt = DateTime.now();
  }

  /// Follows a playback change: settles the pending seek and runs the A-B
  /// loop.
  void onPlayback(PlayerSnapshot snapshot) {
    final pending = _pendingSeek;
    if (pending != null &&
        // Reached the target, moved somewhere else (another seek path), or
        // the player never confirmed it.
        ((snapshot.position - pending).abs() < const Duration(seconds: 1) ||
            !_pendingSeekChain.any(
              (point) =>
                  (snapshot.position - point).abs() <
                  const Duration(milliseconds: 1500),
            ) ||
            _pendingSeekExpired)) {
      _pendingSeek = null;
    }
    // While a loop jump is in flight the stale position must not re-trigger.
    final jump = _pendingSeek == null
        ? _state.ab.jumpFor(snapshot.position)
        : null;
    if (jump != null && snapshot.status == PlaybackStatus.playing) {
      unawaited(seekAbsolute(jump));
    }
  }

  /// Pauses and returns to the start; false when the media cannot seek
  /// (then it is only paused).
  Future<bool> stopToStart({required bool seekable}) async {
    await command(backend.pause);
    if (!seekable) return false;
    await command(() => backend.seek(Duration.zero));
    return true;
  }

  // ---- A-B loop ----------------------------------------------------------------

  AbLoop advanceAb() {
    _set(_state.copyWith(ab: _state.ab.advance(position)));
    return _state.ab;
  }

  void clearAb() => _set(_state.copyWith(ab: const AbLoop()));

  // ---- Sleep timer and repeat ------------------------------------------------

  /// Minutes until playback pauses; -1 for the end of the item, null to
  /// cancel.
  void setSleep(int? minutes) {
    _sleepTimer?.cancel();
    DateTime? at;
    if (minutes != null && minutes != -1) {
      at = DateTime.now().add(Duration(minutes: minutes));
      _sleepTimer = Timer(Duration(minutes: minutes), _sleepNow);
    }
    _set(_state.copyWith(sleepAt: () => at, sleepAtEnd: minutes == -1));
  }

  void _sleepNow() {
    if (_disposed) return;
    _set(_state.copyWith(sleepAt: () => null, sleepAtEnd: false));
    unawaited(command(backend.pause));
    onSleepFinished();
  }

  /// Stops the sleep timer without pausing.
  void cancelSleep() {
    _sleepTimer?.cancel();
    _set(_state.copyWith(sleepAt: () => null, sleepAtEnd: false));
  }

  bool toggleRepeat() {
    _set(_state.copyWith(repeatOne: !_state.repeatOne));
    return _state.repeatOne;
  }

  void setRepeat(bool repeatOne) => _set(_state.copyWith(repeatOne: repeatOne));

  /// The media reached its end: finishes a sleep-at-end timer, or repeats.
  void onEnded({required bool hasMedia}) {
    if (_state.sleepAtEnd) {
      _set(_state.copyWith(sleepAtEnd: false));
      onSleepFinished();
      return;
    }
    if (_state.repeatOne && hasMedia) unawaited(command(backend.play));
  }

  // ---- Volume and snapshot ---------------------------------------------------

  /// Sets the volume (0–100); returns it once applied, null otherwise.
  Future<int?> setVolume(int volume) async {
    volume = volume.clamp(0, 100);
    return await attempt(() => backend.setVolume(volume)) ? volume : null;
  }

  /// Mutes, or restores the volume before muting; returns the new volume
  /// once applied, null otherwise.
  Future<int?> toggleMute() async {
    final volume = backend.value.volume;
    if (volume > 0) _volumeBeforeMute = volume.clamp(1, 100);
    final next = volume == 0 ? _volumeBeforeMute : 0;
    return await attempt(() => backend.setVolume(next)) ? next : null;
  }

  /// Saves the current frame as a PNG named after [title] and returns the
  /// file: in Screenshots under the documents on phones, in Downloads
  /// elsewhere. Throws when the player or the file system fails.
  Future<File> saveSnapshot({
    required String title,
    required bool mobile,
  }) async {
    final bytes = await backend.takeSnapshot();
    final directory = mobile
        ? Directory(
            '${(await getApplicationDocumentsDirectory()).path}/Screenshots',
          )
        : (await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory());
    await directory.create(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    final base = title
        .replaceFirst(RegExp(r'\.[A-Za-z0-9]{2,4}$'), '')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${directory.path}/$base-$stamp.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Forgets the previous media's seek and loop; speed, sleep
  /// timer and repeat carry over.
  void reset() {
    _pendingSeek = null;
    _set(_state.copyWith(ab: const AbLoop()));
  }

  @override
  void dispose() {
    _disposed = true;
    _sleepTimer?.cancel();
    super.dispose();
  }
}
