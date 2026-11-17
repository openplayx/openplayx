import 'package:flutter/foundation.dart';

/// Why the player cannot play the current media.
enum PlayerError {
  /// The picked file could not be opened.
  openFile,

  /// A playback command (open, play, seek…) failed.
  playbackCommand,
}

/// The media the player holds and what it is busy with.
@immutable
class PlayerState {
  const PlayerState({
    this.name,
    this.error,
    this.busy = false,
    this.closing = false,
    this.background = false,
  });

  /// File name of the current media; null when nothing is loaded.
  final String? name;
  final PlayerError? error;

  /// Opening a media.
  final bool busy;

  /// Stopping playback.
  final bool closing;

  /// The app is in the background on a phone; playback stays paused.
  final bool background;

  bool get hasMedia => name != null;

  PlayerState copyWith({
    String? Function()? name,
    PlayerError? Function()? error,
    bool? busy,
    bool? closing,
    bool? background,
  }) => PlayerState(
    name: name == null ? this.name : name(),
    error: error == null ? this.error : error(),
    busy: busy ?? this.busy,
    closing: closing ?? this.closing,
    background: background ?? this.background,
  );
}
