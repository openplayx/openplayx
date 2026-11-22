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
    this.remote = false,
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

  /// The current stream goes through remote access (a relay node), so it
  /// uses server traffic rather than the local network.
  final bool remote;

  bool get hasMedia => name != null;

  PlayerState copyWith({
    String? Function()? name,
    PlayerError? Function()? error,
    bool? busy,
    bool? closing,
    bool? background,
    bool? remote,
  }) => PlayerState(
    name: name == null ? this.name : name(),
    error: error == null ? this.error : error(),
    busy: busy ?? this.busy,
    closing: closing ?? this.closing,
    background: background ?? this.background,
    remote: remote ?? this.remote,
  );
}
