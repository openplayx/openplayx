import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:vlc_player/vlc_player.dart';

import 'read_speed.dart';

enum PlaybackStatus { idle, opening, playing, paused, ended, error }

@immutable
class PlayerAudioTrack {
  const PlayerAudioTrack({required this.id, required this.name, this.language});
  final int id;
  final String name;
  final String? language;
}

@immutable
class PlayerSnapshot {
  const PlayerSnapshot({
    this.status = PlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.canSeek = false,
    this.videoSize,
    this.isBuffering = false,
    this.speed = 1,
    this.volume = 100,
    this.readSpeedMBps,
  });
  final PlaybackStatus status;
  final Duration position;
  final Duration duration;
  final bool canSeek;
  final Size? videoSize;
  final bool isBuffering;
  final double speed;
  final int volume;

  /// Input read speed in decimal MB/s; null until measurable or if unsupported.
  final double? readSpeedMBps;
}

/// Application-facing contract; native VLC types stay inside this package.
abstract class PlayerBackend extends ValueNotifier<PlayerSnapshot> {
  PlayerBackend() : super(const PlayerSnapshot());
  Future<void> open(Uri uri);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setVolume(int volume);
  Future<List<PlayerAudioTrack>> getAudioTracks();
  Future<void> setAudioTrack(int id);
  Widget buildVideo();
}

class LibVlcBackend extends PlayerBackend {
  LibVlcBackend() {
    if (kIsWeb) {
      throw UnsupportedError('OpenPlayX 暂不支持 Web 播放。');
    }
    _controller.addListener(_onValue);
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_sampleReadSpeed());
    });
  }
  final VlcPlayerController _controller = VlcPlayerController(
    // VLCKit defaults to pausing at EOF; request an actual ended event.
    options: ['--ignore-config', '--no-play-and-pause'],
  );
  bool _disposed = false;
  bool _hasStarted = false;
  bool _ended = false;
  Uri? _source;
  late final Timer _statsTimer;
  final _statsClock = Stopwatch()..start();
  final _readSpeedMeter = ReadSpeedMeter();
  bool _statsBusy = false;
  int _session = 0;
  double? _readSpeedMBps;

  Future<void> _sampleReadSpeed() async {
    if (_disposed ||
        _statsBusy ||
        !_controller.isAttached ||
        ![
          PlaybackStatus.opening,
          PlaybackStatus.playing,
          PlaybackStatus.paused,
        ].contains(value.status)) {
      return;
    }
    final session = _session;
    _statsBusy = true;
    try {
      final stats = await _controller.getMediaStats();
      if (_disposed || session != _session) return;
      if (stats.isAvailable) {
        _readSpeedMBps = _readSpeedMeter.sample(
          stats.readBytes,
          _statsClock.elapsed,
        );
      } else {
        _readSpeedMeter.reset();
        _readSpeedMBps = null;
      }
      _onValue();
    } catch (_) {
      // Optional statistics must never interrupt playback.
      if (!_disposed && session == _session) {
        _readSpeedMeter.reset();
        _readSpeedMBps = null;
        _onValue();
      }
    } finally {
      _statsBusy = false;
    }
  }

  /// Web playback is intentionally unsupported. A future Web implementation
  /// needs a separate backend/service design to align with native capabilities.
  static bool get isSupported =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux => true,
        _ => false,
      };

  void _onValue() {
    final native = _controller.value;
    if (native.state == VlcPlaybackState.playing) _hasStarted = true;
    if (native.state == VlcPlaybackState.ended) _ended = true;
    if ([
      VlcPlaybackState.idle,
      VlcPlaybackState.stopped,
      VlcPlaybackState.ended,
      VlcPlaybackState.error,
    ].contains(native.state)) {
      _readSpeedMeter.reset();
      _readSpeedMBps = null;
    }
    value = PlayerSnapshot(
      status: switch (native.state) {
        VlcPlaybackState.idle || VlcPlaybackState.stopped =>
          _ended ? PlaybackStatus.ended : PlaybackStatus.idle,
        VlcPlaybackState.opening => PlaybackStatus.opening,
        // VLCKit may keep reporting buffering while time and video advance.
        // Buffering belongs to an active session and must not disable pause.
        VlcPlaybackState.buffering =>
          _hasStarted ? PlaybackStatus.playing : PlaybackStatus.opening,
        VlcPlaybackState.playing => PlaybackStatus.playing,
        VlcPlaybackState.paused => PlaybackStatus.paused,
        VlcPlaybackState.ended => PlaybackStatus.ended,
        VlcPlaybackState.error => PlaybackStatus.error,
      },
      position: native.position,
      duration: native.duration,
      canSeek: native.isSeekable,
      videoSize: native.videoSize,
      isBuffering: native.isBuffering,
      speed: native.playbackSpeed,
      volume: native.volume,
      readSpeedMBps: _readSpeedMBps,
    );
  }

  @override
  Future<void> open(Uri uri) {
    _session++;
    _readSpeedMeter.reset();
    _readSpeedMBps = null;
    _hasStarted = false;
    _ended = false;
    _source = uri;
    return _controller.setMedia(
      VlcMediaSource(
        uri: uri,
        mediaOptions:
            // VLCKit's native MP4 demuxer can stop reporting network playback time at
            // 250ms. avformat keeps progress and seek events working for these files.
            defaultTargetPlatform == TargetPlatform.macOS &&
                (uri.scheme == 'http' || uri.scheme == 'https') &&
                [
                  '.mp4',
                  '.m4v',
                  '.mov',
                ].any((ext) => uri.path.toLowerCase().endsWith(ext))
            ? [':demux=avformat']
            : [],
      ),
      autoPlay: true,
    );
  }

  @override
  Future<void> play() async {
    if (_ended && _source != null) {
      await open(_source!);
      return;
    }
    await _controller.play();
  }

  @override
  Future<void> pause() async {
    if (_controller.isAttached) await _controller.pause();
  }

  @override
  Future<void> stop() async {
    _session++;
    if (_controller.isAttached) await _controller.stop();
    _source = null;
    _hasStarted = false;
    _ended = false;
    _readSpeedMeter.reset();
    _readSpeedMBps = null;
    value = const PlayerSnapshot();
  }

  @override
  Future<void> seek(Duration position) => _controller.seekTo(position);
  @override
  Future<void> setSpeed(double speed) => _controller.setPlaybackSpeed(speed);
  @override
  Future<void> setVolume(int volume) =>
      _controller.setVolume(volume.clamp(0, 100));
  @override
  Future<List<PlayerAudioTrack>> getAudioTracks() async => [
    for (final track in await _controller.getAudioTracks())
      PlayerAudioTrack(
        id: track.id,
        name: track.name,
        language: track.language,
      ),
  ];
  @override
  Future<void> setAudioTrack(int id) => _controller.setAudioTrack(id);
  @override
  Widget buildVideo() => VlcPlayer(controller: _controller);
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _session++;
    _statsTimer.cancel();
    _statsClock.stop();
    _controller.removeListener(_onValue);
    _controller.dispose();
    super.dispose();
  }
}

class PlayerVideoView extends StatelessWidget {
  const PlayerVideoView({super.key, required this.backend});
  final PlayerBackend backend;
  @override
  Widget build(BuildContext context) => backend.buildVideo();
}
