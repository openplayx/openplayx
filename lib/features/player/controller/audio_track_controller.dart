import 'package:flutter/foundation.dart';
import 'package:openplayx_playback/playback.dart';

import '../model/audio_track_state.dart';
import 'player_attempt.dart';

/// Audio tracks and audio delay of the current media.
class AudioTrackController extends ChangeNotifier {
  AudioTrackController({required this.backend, required this.attempt});

  final PlayerBackend backend;
  final PlayerAttempt attempt;

  AudioTrackState _state = const AudioTrackState();
  AudioTrackState get state => _state;
  bool _disposed = false;

  void _set(AudioTrackState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  /// Re-reads the player's tracks; throws when the player cannot list them.
  Future<void> refresh() async {
    final tracks = await backend.getAudioTracks();
    _set(_state.copyWith(tracks: tracks));
  }

  Future<bool> select(int id) async {
    if (!await attempt(() => backend.setAudioTrack(id)) || _disposed) {
      return false;
    }
    _set(_state.copyWith(selected: id));
    return true;
  }

  Future<bool> setDelay(Duration delay) async {
    if (!backend.supportsDelays) return false;
    if (!await attempt(() => backend.setAudioDelay(delay)) || _disposed) {
      return false;
    }
    _set(_state.copyWith(delay: delay));
    return true;
  }

  /// Forgets everything about the previous media.
  void reset() => _set(const AudioTrackState());

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
