import 'package:openplayx_playback/playback.dart';

/// Measures wall time in each playback state, excluding paused time and seeks.
/// Does not retain media names, URLs, paths or resource identities.
class PlaybackAnalytics {
  PlaybackAnalytics({required this.emit, Duration Function()? clock}) {
    final timer = Stopwatch()..start();
    _clock = clock ?? (() => timer.elapsed);
  }
  final void Function(String, Map<String, Object>) emit;
  late final Duration Function() _clock;
  Duration? _started, _last, _lastReport;
  PlayerSnapshot _previous = const PlayerSnapshot();
  int _playing = 0, _buffering = 0, _bufferCount = 0;
  bool _hasPlayed = false;
  String? _id;
  static int _sequence = 0;

  void begin() {
    finish();
    _started = _last = _lastReport = _clock();
    _playing = _buffering = _bufferCount = 0;
    _hasPlayed = false;
    _previous = const PlayerSnapshot();
    _id =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_sequence++}';
    emit('playback_requested', {'playback_id': _id!});
  }

  void _account(Duration now) {
    if (_last == null) return;
    final ms = (now - _last!).inMilliseconds;
    if (_hasPlayed && _previous.isBuffering) {
      _buffering += ms;
    } else if (_hasPlayed && _previous.status == PlaybackStatus.playing) {
      _playing += ms;
    }
    _last = now;
  }

  Map<String, Object> get _summary => {
    'playback_id': _id!,
    'playing_ms': _playing,
    'buffering_ms': _buffering,
    'buffering_count': _bufferCount,
    'position_ms': _previous.position.inMilliseconds,
    'media_duration_ms': _previous.duration.inMilliseconds,
    if (_previous.duration.inMilliseconds > 0)
      'progress_percent':
          (_previous.position.inMilliseconds /
                  _previous.duration.inMilliseconds *
                  100)
              .clamp(0, 100),
  };

  void update(PlayerSnapshot value) {
    if (_id == null) return;
    final now = _clock();
    _account(now);
    if (_hasPlayed && value.isBuffering && !_previous.isBuffering)
      _bufferCount++;
    _previous = value;
    if (!_hasPlayed &&
        value.status == PlaybackStatus.playing &&
        !value.isBuffering) {
      _hasPlayed = true;
      emit('playback_started', {
        'playback_id': _id!,
        'startup_ms': (now - _started!).inMilliseconds,
      });
    }
    if (value.status == PlaybackStatus.ended) {
      finish(completed: true);
    } else if (value.status == PlaybackStatus.error) {
      emit('playback_failed', {
        'playback_id': _id!,
        'error_category': 'playback',
      });
      finish();
    } else if (now - _lastReport! >= const Duration(minutes: 1)) {
      _lastReport = now;
      // Progress reports are cumulative; final summaries are a separate event.
      emit('playback_progress', _summary);
    }
  }

  void finish({bool completed = false}) {
    if (_id == null) return;
    _account(_clock());
    emit('playback_finished', {..._summary, 'completed': completed});
    _id = null;
    _last = null;
  }
}
