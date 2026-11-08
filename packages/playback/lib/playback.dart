import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:vlc_player/vlc_player.dart';

enum PlaybackStatus { idle, opening, playing, paused, ended, error }

@immutable
class PlayerSnapshot {
  const PlayerSnapshot({
    this.status = PlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.canSeek = false,
    this.videoSize,
    this.isBuffering = false,
  });
  final PlaybackStatus status;
  final Duration position;
  final Duration duration;
  final bool canSeek;
  final Size? videoSize;
  final bool isBuffering;
}

/// Application-facing contract; native VLC types stay inside this package.
abstract class PlayerBackend extends ValueNotifier<PlayerSnapshot> {
  PlayerBackend() : super(const PlayerSnapshot());
  Future<void> open(Uri uri);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Widget buildVideo();
}

class LibVlcBackend extends PlayerBackend {
  LibVlcBackend() {
    if (kIsWeb) {
      throw UnsupportedError('OpenPlayX 暂不支持 Web 播放。');
    }
    _controller.addListener(_onValue);
  }
  final VlcPlayerController _controller = VlcPlayerController(
    // VLCKit defaults to pausing at EOF; request an actual ended event.
    options: ['--ignore-config', '--no-play-and-pause'],
  );
  bool _disposed = false;
  bool _hasStarted = false;
  bool _ended = false;
  Uri? _source;

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
    );
  }

  @override
  Future<void> open(Uri uri) {
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
  Future<void> seek(Duration position) => _controller.seekTo(position);
  @override
  Widget buildVideo() => VlcPlayer(controller: _controller);
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
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
