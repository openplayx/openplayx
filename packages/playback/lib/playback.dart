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
class PlayerSubtitleTrack {
  const PlayerSubtitleTrack({
    required this.id,
    required this.name,
    this.language,
  });
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

/// One elementary stream of the current media, as far as VLC could discover.
@immutable
class PlayerTrackInfo {
  const PlayerTrackInfo({
    required this.type,
    this.codec,
    this.language,
    this.bitrate,
    this.width,
    this.height,
    this.channels,
    this.sampleRate,
  });

  /// `video`, `audio`, `subtitle` or `unknown`.
  final String type;
  final String? codec, language;
  final int? bitrate, width, height, channels, sampleRate;
}

@immutable
class PlayerMediaInfo {
  const PlayerMediaInfo({this.title, this.tracks = const []});
  final String? title;
  final List<PlayerTrackInfo> tracks;
}

/// Decoder and input counters of the current media. Bitrates are kbit/s.
@immutable
class PlayerStats {
  const PlayerStats({
    this.inputKbps = 0,
    this.demuxKbps = 0,
    this.readBytes = 0,
    this.decodedVideo = 0,
    this.decodedAudio = 0,
    this.displayedPictures = 0,
    this.lostPictures = 0,
    this.playedAudioBuffers = 0,
    this.lostAudioBuffers = 0,
  });
  final double inputKbps, demuxKbps;
  final int readBytes,
      decodedVideo,
      decodedAudio,
      displayedPictures,
      lostPictures,
      playedAudioBuffers,
      lostAudioBuffers;
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

  /// Embedded and auto-detected subtitle tracks, without a "disabled" entry.
  Future<List<PlayerSubtitleTrack>> getSubtitleTracks();
  Future<void> setSubtitleTrack(int id);
  Future<void> disableSubtitle();

  /// Whether [addExternalSubtitle] works in this backend/session.
  bool get supportsExternalSubtitles => false;

  /// Adds a subtitle file (e.g. a saved recognised subtitle) to the current
  /// media and selects it. It then also appears in [getSubtitleTracks].
  Future<void> addExternalSubtitle(Uri file) =>
      Future.error(UnsupportedError('external subtitles'));

  /// Whether audio/subtitle delays, snapshots and media details work.
  bool get supportsDelays => false;
  bool get supportsSnapshot => false;
  bool get supportsMediaInfo => false;

  /// Positive values play the audio (or show subtitles) later.
  Future<void> setAudioDelay(Duration delay) =>
      Future.error(UnsupportedError('audio delay'));
  Future<void> setSubtitleDelay(Duration delay) =>
      Future.error(UnsupportedError('subtitle delay'));

  /// PNG bytes of the current video frame.
  Future<Uint8List> takeSnapshot() =>
      Future.error(UnsupportedError('snapshot'));
  Future<PlayerMediaInfo> getMediaInfo() =>
      Future.error(UnsupportedError('media info'));

  /// Null while no statistics are available for the current media.
  Future<PlayerStats?> getStats() => Future.error(UnsupportedError('stats'));
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

  /// Last explicit playing/paused state. VLCKit reports buffering during
  /// seeks; a seek while paused must stay paused, or the UI would show
  /// "playing" and keep sending pause.
  PlaybackStatus _lastActive = PlaybackStatus.playing;
  PlaybackStatus? _subtitlePlaybackStatus;
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
    if (native.state == VlcPlaybackState.playing) {
      _hasStarted = true;
      _lastActive = PlaybackStatus.playing;
    } else if (native.state == VlcPlaybackState.paused) {
      _lastActive = PlaybackStatus.paused;
    }
    if (native.state == VlcPlaybackState.ended) _ended = true;
    if (_subtitlePlaybackStatus != null) {
      if (native.state == VlcPlaybackState.playing) {
        _subtitlePlaybackStatus = PlaybackStatus.playing;
      } else if (native.state == VlcPlaybackState.paused) {
        _subtitlePlaybackStatus = PlaybackStatus.paused;
      } else if (native.state == VlcPlaybackState.stopped ||
          native.state == VlcPlaybackState.error ||
          native.state == VlcPlaybackState.ended) {
        _subtitlePlaybackStatus = null;
      }
    }
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
        // VLCKit reports ESAdded after adding an external subtitle; vlc_player
        // maps that unknown enum to idle even while playback time advances.
        // Preserve the active state for that subtitle load only. Explicit
        // stop, pause, end and error events still take precedence.
        VlcPlaybackState.idle =>
          _ended
              ? PlaybackStatus.ended
              : _subtitlePlaybackStatus ?? PlaybackStatus.idle,
        VlcPlaybackState.stopped =>
          _ended ? PlaybackStatus.ended : PlaybackStatus.idle,
        VlcPlaybackState.opening => PlaybackStatus.opening,
        // VLCKit may keep reporting buffering while time and video advance.
        // Buffering belongs to an active session and must not disable pause.
        VlcPlaybackState.buffering =>
          _hasStarted ? _lastActive : PlaybackStatus.opening,
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
    _lastActive = PlaybackStatus.playing;
    _subtitlePlaybackStatus = null;
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
    _subtitlePlaybackStatus = null;
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
      // libVLC lists a "Disable" entry with a negative id, which the plugin
      // refuses to select; muting is done through the volume instead.
      if (track.id >= 0)
        PlayerAudioTrack(
          id: track.id,
          name: track.name,
          language: track.language,
        ),
  ];
  @override
  Future<void> setAudioTrack(int id) => _controller.setAudioTrack(id);
  @override
  Future<List<PlayerSubtitleTrack>> getSubtitleTracks() async => [
    for (final track in await _controller.getSubtitleTracks())
      // libVLC lists its own "disable" entry with a negative id; the app shows
      // a dedicated "off" row instead.
      if (track.id >= 0)
        PlayerSubtitleTrack(
          id: track.id,
          name: track.name,
          language: track.language,
        ),
  ];
  @override
  Future<void> setSubtitleTrack(int id) => _controller.setSubtitleTrack(id);
  @override
  Future<void> disableSubtitle() => _controller.disableSubtitle();
  @override
  bool get supportsExternalSubtitles => true;
  @override
  Future<void> addExternalSubtitle(Uri file) async {
    final before = value.status;
    // VLCKit (macOS and iOS) reports ESAdded, which vlc_player maps to idle.
    // Arm the override before the call: the event can arrive before the
    // method channel reply.
    final guard =
        [
          TargetPlatform.macOS,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform) &&
        [PlaybackStatus.playing, PlaybackStatus.paused].contains(before);
    if (guard) _subtitlePlaybackStatus = before;
    try {
      await _controller.addSubtitle(file);
    } catch (_) {
      if (guard) _subtitlePlaybackStatus = null;
      rethrow;
    }
    if (guard) _onValue();
  }

  @override
  bool get supportsDelays => true;
  @override
  bool get supportsSnapshot => true;
  @override
  bool get supportsMediaInfo => true;
  @override
  Future<void> setAudioDelay(Duration delay) =>
      _controller.setAudioDelay(delay);
  @override
  Future<void> setSubtitleDelay(Duration delay) =>
      _controller.setSubtitleDelay(delay);
  @override
  Future<Uint8List> takeSnapshot() {
    // VLCKit raises an Objective-C exception (and the app aborts) when no
    // video output exists, e.g. after the end of the media.
    if (!_controller.isAttached ||
        value.videoSize == null ||
        ![
          PlaybackStatus.playing,
          PlaybackStatus.paused,
        ].contains(value.status)) {
      return Future.error(StateError('No video frame to snapshot'));
    }
    return _controller.takeSnapshot();
  }

  @override
  Future<PlayerMediaInfo> getMediaInfo() async {
    final info = await _controller.getMediaInfo();
    return PlayerMediaInfo(
      title: info.title,
      tracks: [
        for (final track in [
          ...info.videoTracks,
          ...info.audioTracks,
          ...info.subtitleTracks,
        ])
          PlayerTrackInfo(
            type: track.type,
            codec: track.codec,
            language: track.language,
            bitrate: track.bitrate,
            width: track.width,
            height: track.height,
            channels: track.channels,
            sampleRate: track.sampleRate,
          ),
      ],
    );
  }

  @override
  Future<PlayerStats?> getStats() async {
    final stats = await _controller.getMediaStats();
    if (!stats.isAvailable) return null;
    // libVLC reports bitrates in bytes per microsecond × 1000 (as VLC's own
    // statistics panel does): × 8000 gives kbit/s.
    return PlayerStats(
      inputKbps: stats.inputBitrate * 8000,
      demuxKbps: stats.demuxBitrate * 8000,
      readBytes: stats.readBytes,
      decodedVideo: stats.decodedVideo,
      decodedAudio: stats.decodedAudio,
      displayedPictures: stats.displayedPictures,
      lostPictures: stats.lostPictures,
      playedAudioBuffers: stats.playedAudioBuffers,
      lostAudioBuffers: stats.lostAudioBuffers,
    );
  }

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
