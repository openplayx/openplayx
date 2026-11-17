import 'package:flutter/foundation.dart';
import 'package:openplayx_playback/playback.dart';

/// Audio track state of the current media.
@immutable
class AudioTrackState {
  const AudioTrackState({
    this.tracks = const [],
    this.selected,
    this.delay = Duration.zero,
  });

  /// Tracks as last listed by the player.
  final List<PlayerAudioTrack> tracks;

  /// The chosen track id; null for the media's default.
  final int? selected;
  final Duration delay;

  /// Track after the current one, wrapping around; null without tracks.
  int? get nextTrack {
    if (tracks.isEmpty) return null;
    final index = tracks.indexWhere((t) => t.id == selected);
    return tracks[(index + 1) % tracks.length].id;
  }

  AudioTrackState copyWith({
    List<PlayerAudioTrack>? tracks,
    int? selected,
    Duration? delay,
  }) => AudioTrackState(
    tracks: tracks ?? this.tracks,
    selected: selected ?? this.selected,
    delay: delay ?? this.delay,
  );
}
