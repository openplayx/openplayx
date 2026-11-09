import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openplayx_playback/playback.dart';

import '../../data/files/local_media_picker.dart';
import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_manager.dart';
import '../sources/source_page.dart';
import '../library/library_page.dart';
import '../../services/library/library_service.dart';
import '../../data/sources/source_config.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    this.backend,
    this.pickMedia = pickLocalMedia,
    this.sourceManager,
    this.libraryService,
  });
  final PlayerBackend? backend;
  final SourceManager? sourceManager;
  final LibraryService? libraryService;
  final Future<LocalMedia?> Function() pickMedia;
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  late final PlayerBackend _backend;
  late final SourceManager _sources;
  LibraryService? _library;
  Future<LibraryService>? _openingLibrary;
  String? _resource;
  String? _session;
  Duration? _resume;
  bool _resuming = false;
  int _trackingGeneration = 0;
  DateTime? _lastCheckpoint;
  Future<LibraryService> _ensureLibrary() async {
    if (_library != null) return _library!;
    try {
      final service = await (_openingLibrary ??= LibraryService.open());
      if (!mounted) {
        service.close();
        throw StateError('播放器已关闭');
      }
      return _library = service;
    } catch (_) {
      _openingLibrary = null;
      rethrow;
    }
  }

  void _checkpoint({bool force = false}) {
    final value = _backend.value;
    if (_resource == null ||
        _session == null ||
        _resume != null ||
        _resuming ||
        ![
          PlaybackStatus.playing,
          PlaybackStatus.paused,
          PlaybackStatus.ended,
        ].contains(value.status)) {
      return;
    }
    final now = DateTime.now();
    if (!force &&
        _lastCheckpoint != null &&
        now.difference(_lastCheckpoint!).inSeconds < 5) {
      return;
    }
    _lastCheckpoint = now;
    try {
      _library?.saveProgress(
        _resource!,
        _session!,
        value.position,
        value.duration,
        completed: value.status == PlaybackStatus.ended,
      );
    } catch (_) {
      _resource = null;
      _session = null;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('观看记录暂时无法保存，仍可继续播放')));
      }
    }
  }

  void _finishTracking() {
    _checkpoint(force: true);
    _trackingGeneration++;
    _resource = null;
    _resuming = false;
    _session = null;
    _resume = null;
    _lastCheckpoint = null;
  }

  Future<void> _track(
    ResourceRef ref,
    String name, {
    String? localPath,
    int? generation,
    SourceEntry? entry,
  }) async {
    generation ??= _trackingGeneration;
    try {
      final service = await _ensureLibrary();
      if (!mounted || generation != _trackingGeneration) return;
      final media = service.register(
        entry ?? SourceEntry(ref, name, isFolder: false),
        localPath: localPath,
      );
      final resource =
          service.resourceFor(ref) ?? service.resources(media).first;
      final id = resource['id'] as String;
      final checkpoint = service.checkpoint(id);
      _resource = id;
      if (checkpoint != null &&
          checkpoint['completed'] == 0 &&
          (checkpoint['position'] as int) > 0) {
        _resume = Duration(milliseconds: checkpoint['position'] as int);
      }
      _session = service.beginSession(id);
      _onPlayback();
    } catch (_) {
      _openingLibrary = null;
      // A storage error must not prevent direct playback.
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('观看记录暂时无法保存，仍可继续播放')));
      }
    }
  }

  Future<void> _trackLocal(LocalMedia media) async {
    final generation = _trackingGeneration;
    var path = media.uri.toFilePath();
    try {
      path = await File(path).resolveSymbolicLinks();
    } catch (_) {}
    if (!mounted || generation != _trackingGeneration) return;
    await _track(
      ResourceRef('@local', path),
      media.name,
      localPath: path,
      generation: generation,
    );
  }

  PlayableStream? _stream;
  String? _name;
  String? _error;
  bool _busy = false;
  bool _background = false;
  double? _drag;
  Timer? _hideTimer;
  bool _controlsVisible = true;
  bool _pointerDown = false;
  bool _hoveringControls = false;
  int _openPanels = 0;
  PlaybackStatus _lastStatus = PlaybackStatus.idle;
  bool _locked = false;
  bool _boosting = false;
  double _speed = 1;
  double _brightness = 1;
  int? _selectedAudioTrack;
  Future<void> _speedCommands = Future.value();

  final _playerFocus = FocusNode(debugLabel: 'player-keyboard');
  int _volumeBeforeMute = 100;

  KeyEventResult _handlePlayerKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent ||
        ModalRoute.of(context)?.isCurrent != true ||
        _busy ||
        _openPanels > 0) {
      return KeyEventResult.ignored;
    }
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext?.widget is EditableText ||
        focusContext?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed ||
        keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_locked) {
        setState(() {
          _locked = false;
          _controlsVisible = true;
        });
        _scheduleHide();
        return KeyEventResult.handled;
      }
      _showControls();
      return KeyEventResult.ignored;
    }
    final toggle =
        key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK;
    final supported =
        toggle ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyM ||
        key == LogicalKeyboardKey.keyL;
    if (!supported) return KeyEventResult.ignored;
    if (_locked || !_enabled) return KeyEventResult.handled;
    // Holding a toggle key must not repeatedly alternate play/mute/lock.
    if (event is KeyRepeatEvent &&
        (toggle ||
            key == LogicalKeyboardKey.keyM ||
            key == LogicalKeyboardKey.keyL)) {
      return KeyEventResult.handled;
    }
    _showControls();
    if (toggle) {
      _togglePlayback();
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      _skip(key == LogicalKeyboardKey.arrowLeft ? -10 : 10);
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final volume =
          (_backend.value.volume + (key == LogicalKeyboardKey.arrowUp ? 5 : -5))
              .clamp(0, 100);
      unawaited(_adjust(() => _backend.setVolume(volume)));
    } else if (key == LogicalKeyboardKey.keyM) {
      final volume = _backend.value.volume;
      if (volume > 0) _volumeBeforeMute = volume.clamp(1, 100);
      unawaited(
        _adjust(() => _backend.setVolume(volume == 0 ? _volumeBeforeMute : 0)),
      );
    } else if (key == LogicalKeyboardKey.keyL) {
      _lock();
    }
    return KeyEventResult.handled;
  }

  void _togglePlayback() {
    if (!_enabled) return;
    _endBoost();
    unawaited(
      _command(
        _backend.value.status == PlaybackStatus.playing
            ? _backend.pause
            : _backend.play,
      ),
    );
  }

  bool get _enabled =>
      _name != null &&
      !_busy &&
      !_background &&
      !_locked &&
      _error == null &&
      switch (_backend.value.status) {
        PlaybackStatus.playing ||
        PlaybackStatus.paused ||
        PlaybackStatus.ended => true,
        _ => false,
      };

  Future<bool> _adjust(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (error, stack) {
      debugPrint('Player adjustment failed: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('调整失败，请重试。')));
      }
      return false;
    }
  }

  // Serialize native rate changes so a slow press cannot overtake its release.
  Future<void> _applySpeed(double speed) {
    return _speedCommands = _speedCommands.then((_) async {
      if (mounted) await _adjust(() => _backend.setSpeed(speed));
    });
  }

  void _startBoost() {
    if (!_enabled || _backend.value.status != PlaybackStatus.playing) return;
    _hideTimer?.cancel();
    setState(() => _boosting = true);
    unawaited(_applySpeed(2));
  }

  void _endBoost() {
    if (!_boosting) return;
    setState(() => _boosting = false);
    unawaited(_applySpeed(_speed));
    _scheduleHide();
  }

  void _skip(int seconds) {
    final value = _backend.value;
    if (!_enabled || !value.canSeek || value.duration <= Duration.zero) return;
    final target = (value.position.inMilliseconds + seconds * 1000).clamp(
      0,
      value.duration.inMilliseconds,
    );
    unawaited(_command(() => _backend.seek(Duration(milliseconds: target))));
  }

  Future<void> _showAudioTracks() async {
    List<PlayerAudioTrack> tracks = [];
    if (!await _adjust(() async {
      tracks = await _backend.getAudioTracks();
    })) {
      return;
    }
    if (!mounted || !_enabled) return;
    _panelOpened();
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('音轨')),
              if (tracks.isEmpty) const ListTile(title: Text('此媒体没有可选音轨')),
              for (final track in tracks)
                ListTile(
                  title: Text(
                    track.name.isEmpty ? '音轨 ${track.id}' : track.name,
                  ),
                  subtitle: track.language == null
                      ? null
                      : Text(track.language!),
                  trailing: _selectedAudioTrack == track.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, track.id),
                ),
            ],
          ),
        ),
      ),
    );
    _panelClosed();
    if (id != null &&
        _enabled &&
        await _adjust(() => _backend.setAudioTrack(id))) {
      if (mounted) setState(() => _selectedAudioTrack = id);
    }
  }

  @override
  void initState() {
    super.initState();
    _backend = widget.backend ?? LibVlcBackend();
    _sources = widget.sourceManager ?? SourceManager();
    _library = widget.libraryService;
    _backend.addListener(_onPlayback);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onPlayback() {
    final snapshot = _backend.value;
    if (_resume != null &&
        snapshot.canSeek &&
        snapshot.duration > Duration.zero &&
        [
          PlaybackStatus.playing,
          PlaybackStatus.paused,
        ].contains(snapshot.status)) {
      final target = _resume!;
      _resume = null;
      _resuming = true;
      // Only this exact resource's timeline is eligible for continuation.
      final generation = _trackingGeneration;
      unawaited(
        _adjust(
          () => _backend.seek(
            target < snapshot.duration ? target : Duration.zero,
          ),
        ).whenComplete(() {
          if (generation == _trackingGeneration) {
            _resuming = false;
            _checkpoint(force: true);
          }
        }),
      );
      return;
    }
    _checkpoint(
      force:
          snapshot.status == PlaybackStatus.paused ||
          snapshot.status == PlaybackStatus.ended,
    );
    if (_lastStatus != _backend.value.status) {
      _lastStatus = _backend.value.status;
      if (mounted) setState(() => _controlsVisible = true);
      _scheduleHide();
    }
    if (_boosting && _backend.value.status != PlaybackStatus.playing) {
      _endBoost();
    }
    if (_background && _backend.value.status == PlaybackStatus.playing) {
      unawaited(_command(_backend.pause));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background =
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
    if (_background || state == AppLifecycleState.inactive) _endBoost();
    if (_background) _checkpoint(force: true);
    if (_background && _name != null) unawaited(_command(_backend.pause));
  }

  Future<void> _command(Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stack) {
      debugPrint('Playback command failed: $error\n$stack');
      if (mounted) {
        setState(() {
          _controlsVisible = true;
          _error = '播放操作失败，请重新打开媒体文件。';
        });
      }
    }
  }

  Future<void> _open() async {
    _endBoost();
    await _speedCommands;
    if (!mounted) return;
    _hideTimer?.cancel();
    setState(() {
      _busy = true;
      _controlsVisible = true;
    });
    try {
      final media = await widget.pickMedia();
      if (media == null || !mounted) return;
      _finishTracking();
      setState(() {
        _name = media.name;
        _error = null;
        _drag = null;
        _selectedAudioTrack = null;
      });
      await _command(() async {
        await _backend.open(media.uri);
        await _backend.setSpeed(_speed);
        await _stream?.release();
        _stream = null;
      });
      if (_error == null && media.uri.scheme == 'file') {
        unawaited(_trackLocal(media));
      }
      if (_background && mounted) await _command(_backend.pause);
    } catch (error, stack) {
      debugPrint('File selection failed: $error\n$stack');
      if (mounted) setState(() => _error = '无法打开文件，请重新选择。');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scheduleHide();
      }
    }
  }

  Future<void> _openSource({bool library = false}) async {
    _endBoost();
    await _speedCommands;
    if (!mounted) return;
    _hideTimer?.cancel();
    setState(() {
      _busy = true;
      _controlsVisible = true;
    });
    try {
      _checkpoint(force: true);
      final service = library ? await _ensureLibrary() : _library;
      if (!mounted) return;
      final selection = await Navigator.of(context).push<SourceSelection>(
        MaterialPageRoute(
          builder: (_) => library
              ? LibraryPage(sources: _sources, service: service)
              : SourcePage(manager: _sources),
        ),
      );
      if (selection == null) return;
      if (!mounted) {
        await selection.stream.release();
        return;
      }
      _finishTracking();
      final previous = _stream;
      _stream = selection.stream;
      setState(() {
        _name = selection.name;
        _error = null;
        _drag = null;
        _selectedAudioTrack = null;
      });
      await _command(() async {
        await _backend.open(selection.stream.uri);
        await _backend.setSpeed(_speed);
      });
      await previous?.release();
      if (_error == null && selection.ref != null) {
        String? localPath;
        final config = _sources.configs
            .where((c) => c.id == selection.ref!.instanceId)
            .firstOrNull;
        if (config?.kind == SourceKind.local ||
            selection.ref!.instanceId == '@local') {
          localPath = selection.ref!.id;
        }
        unawaited(
          _track(
            selection.ref!,
            selection.name,
            localPath: localPath,
            entry: selection.entry,
          ),
        );
      }
      if (_background && mounted) await _command(_backend.pause);
    } catch (_) {
      if (mounted) setState(() => _error = '无法打开媒体库或来源，请重试');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scheduleHide();
      }
    }
  }

  @override
  void dispose() {
    _playerFocus.dispose();
    _finishTracking();
    if (widget.libraryService == null) _library?.close();
    _hideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _backend.removeListener(_onPlayback);
    _backend.dispose();
    unawaited(_releaseSources());
    super.dispose();
  }

  Future<void> _releaseSources() async {
    await _stream?.release();
    if (widget.sourceManager == null) await _sources.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!mounted) return;
    if (_locked ||
        _busy ||
        _boosting ||
        _drag != null ||
        _pointerDown ||
        _hoveringControls ||
        _openPanels > 0 ||
        _error != null ||
        _backend.value.status != PlaybackStatus.playing) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    if (_locked) return;
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _panelOpened() {
    _openPanels++;
    _hideTimer?.cancel();
  }

  void _panelClosed() {
    if (_openPanels > 0) _openPanels--;
    _scheduleHide();
  }

  void _lock() {
    _endBoost();
    _hideTimer?.cancel();
    setState(() {
      _drag = null;
      _locked = true;
      _hoveringControls = false;
    });
  }

  Future<void> _showLevel(bool volume) async {
    _panelOpened();
    try {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (context) => Dialog(
          alignment: Alignment.bottomRight,
          insetPadding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          child: SizedBox(
            width: 280,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: StatefulBuilder(
                builder: (context, update) =>
                    ValueListenableBuilder<PlayerSnapshot>(
                      valueListenable: _backend,
                      builder: (context, snapshot, _) {
                        final level = volume
                            ? snapshot.volume.clamp(0, 100).toDouble()
                            : _brightness * 100;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  volume
                                      ? Icons.volume_up_outlined
                                      : Icons.brightness_6_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(volume ? '音量' : '画面亮度'),
                                const Spacer(),
                                Text('${level.round()}%'),
                              ],
                            ),
                            Slider(
                              key: Key(
                                volume
                                    ? 'playback-volume'
                                    : 'playback-brightness',
                              ),
                              value: level,
                              max: 100,
                              onChanged: _enabled
                                  ? (value) {
                                      if (volume) {
                                        unawaited(
                                          _adjust(
                                            () => _backend.setVolume(
                                              value.round(),
                                            ),
                                          ),
                                        );
                                      } else {
                                        setState(
                                          () => _brightness = value / 100,
                                        );
                                        update(() {});
                                      }
                                    }
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
              ),
            ),
          ),
        ),
      );
    } finally {
      _panelClosed();
    }
  }

  Widget _chrome(Widget child) => MouseRegion(
    onEnter: (_) {
      _hoveringControls = true;
      _hideTimer?.cancel();
    },
    onExit: (_) {
      _hoveringControls = false;
      _scheduleHide();
    },
    child: IgnorePointer(
      ignoring: !_controlsVisible,
      child: ExcludeSemantics(
        excluding: !_controlsVisible,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: child,
        ),
      ),
    ),
  );

  Widget _icon(String tooltip, IconData icon, VoidCallback? action) =>
      IconButton(
        tooltip: tooltip,
        onPressed: action,
        icon: Icon(icon, size: 22),
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white30,
        ),
      );

  Widget _transport(PlayerSnapshot value) {
    final seekable =
        _enabled && value.canSeek && value.duration > Duration.zero;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _icon('快退 10 秒', Icons.replay_10, seekable ? () => _skip(-10) : null),
        _icon(
          value.status == PlaybackStatus.playing ? '暂停' : '播放',
          value.status == PlaybackStatus.playing
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          _enabled ? _togglePlayback : null,
        ),
        _icon('快进 10 秒', Icons.forward_10, seekable ? () => _skip(10) : null),
      ],
    );
  }

  Widget _speedMenu() => PopupMenuButton<double>(
    tooltip: '播放速度',
    enabled: _enabled,
    initialValue: _speed,
    onOpened: _panelOpened,
    onCanceled: _panelClosed,
    onSelected: (speed) async {
      try {
        await _speedCommands;
        if (!mounted || !_enabled) return;
        if (await _adjust(() => _backend.setSpeed(speed))) {
          if (mounted) setState(() => _speed = speed);
        }
      } finally {
        _panelClosed();
      }
    },
    itemBuilder: (_) => [
      for (final speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
        PopupMenuItem(value: speed, child: Text('$speed×')),
    ],
    child: SizedBox(
      width: 48,
      height: 44,
      child: Center(
        child: Text(
          '$_speed×',
          style: TextStyle(color: _enabled ? Colors.white : Colors.white30),
        ),
      ),
    ),
  );

  Widget _moreMenu() => PopupMenuButton<String>(
    tooltip: '更多播放设置',
    enabled: _enabled,
    onOpened: _panelOpened,
    onCanceled: _panelClosed,
    icon: const Icon(Icons.more_horiz),
    onSelected: (action) {
      _panelClosed();
      switch (action) {
        case 'audio':
          unawaited(_showAudioTracks());
        case 'brightness':
          unawaited(_showLevel(false));
        case 'lock':
          _lock();
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'audio', child: Text('音轨')),
      PopupMenuItem(value: 'brightness', child: Text('画面亮度')),
      PopupMenuItem(value: 'lock', child: Text('锁定控制')),
    ],
  );

  Widget _bottomControls(PlayerSnapshot value) {
    final duration = value.duration.inMilliseconds.toDouble();
    final position = (_drag ?? value.position.inMilliseconds.toDouble()).clamp(
      0.0,
      duration > 0 ? duration : 1.0,
    );
    final seekable = _enabled && value.canSeek && duration > 0;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xD9000000)],
        ),
      ),
      child: Padding(
        key: const Key('player-control-bar'),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final remaining =
                    '剩余 ${formatTime(Duration(milliseconds: (duration - position).round()))}';
                return Row(
                  children: [
                    Flexible(
                      child: Tooltip(
                        message: remaining,
                        child: Text(
                          '${formatTime(Duration(milliseconds: position.round()))} / ${duration > 0 ? formatTime(value.duration) : '--:--'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '读取 ${value.readSpeedMBps == null ? '--' : value.readSpeedMBps!.toStringAsFixed(2)} MB/s',
                      key: const Key('playback-read-speed'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                    if (duration > 0 && constraints.maxWidth >= 456) ...[
                      const SizedBox(width: 16),
                      Text(
                        remaining,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            SizedBox(
              height: 28,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 4,
                  ),
                ),
                child: Slider(
                  key: const Key('playback-progress'),
                  value: position,
                  max: duration > 0 ? duration : 1,
                  onChanged: seekable ? (v) => setState(() => _drag = v) : null,
                  onChangeEnd: seekable
                      ? (v) async {
                          await _command(
                            () => _backend.seek(
                              Duration(milliseconds: v.round()),
                            ),
                          );
                          if (mounted) setState(() => _drag = null);
                          _scheduleHide();
                        }
                      : null,
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 456;
                return Row(
                  children: [
                    _transport(value),
                    const Spacer(),
                    _speedMenu(),
                    _icon(
                      '播放器音量',
                      value.volume == 0
                          ? Icons.volume_off_outlined
                          : Icons.volume_up_outlined,
                      _enabled ? () => _showLevel(true) : null,
                    ),
                    if (wide) ...[
                      _icon(
                        '画面亮度',
                        Icons.brightness_6_outlined,
                        _enabled ? () => _showLevel(false) : null,
                      ),
                      _icon(
                        '音轨',
                        Icons.audiotrack_outlined,
                        _enabled ? _showAudioTracks : null,
                      ),
                      _icon(
                        '锁定控制',
                        Icons.lock_outline,
                        _enabled ? _lock : null,
                      ),
                    ] else
                      _moreMenu(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _playerFocus,
    autofocus: true,
    onKeyEvent: _handlePlayerKey,
    child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: MouseRegion(
          onHover: (_) => _showControls(),
          child: Listener(
            onPointerDown: (_) {
              _playerFocus.requestFocus();
              _pointerDown = true;
              _hideTimer?.cancel();
            },
            onPointerUp: (_) {
              _pointerDown = false;
              _endBoost();
              _scheduleHide();
            },
            onPointerCancel: (_) {
              _pointerDown = false;
              _endBoost();
              _scheduleHide();
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  key: const Key('video-gestures'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _locked
                      ? null
                      : () {
                          if (_controlsVisible &&
                              _name != null &&
                              _error == null) {
                            _hideTimer?.cancel();
                            setState(() => _controlsVisible = false);
                          } else {
                            _showControls();
                          }
                        },
                  onLongPressStart: _locked ? null : (_) => _startBoost(),
                  onLongPressEnd: (_) => _endBoost(),
                  onLongPressCancel: _endBoost,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      IgnorePointer(child: PlayerVideoView(backend: _backend)),
                      IgnorePointer(
                        child: ColoredBox(
                          key: const Key('video-dimming'),
                          color: Colors.black.withValues(
                            alpha: (1 - _brightness) * 0.85,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_name == null)
                  const IgnorePointer(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_outline,
                              size: 56,
                              color: Colors.white38,
                            ),
                            SizedBox(height: 12),
                            Text(
                              '打开一个视频，开始播放',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (!_locked)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _chrome(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x99000000), Colors.transparent],
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _name ?? 'OpenPlayX',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            _icon(
                              '媒体源',
                              Icons.video_library_outlined,
                              _busy ? null : () => _openSource(),
                            ),
                            _icon(
                              '媒体库',
                              Icons.video_library_outlined,
                              _busy ? null : () => _openSource(library: true),
                            ),
                            _icon(
                              '打开文件',
                              Icons.folder_open_outlined,
                              _busy ? null : _open,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (!_locked)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _chrome(
                      ValueListenableBuilder<PlayerSnapshot>(
                        valueListenable: _backend,
                        builder: (context, value, _) => _bottomControls(value),
                      ),
                    ),
                  ),
                if (_busy || _backend.value.status == PlaybackStatus.opening)
                  const IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                if (_error != null ||
                    _backend.value.status == PlaybackStatus.error)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error ?? '播放失败，请检查文件或重新选择。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                if (_boosting)
                  const Positioned(
                    top: 64,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(child: Chip(label: Text('临时 2× · 松手恢复'))),
                    ),
                  ),
                if (_locked)
                  Positioned(
                    top: 8,
                    left: 12,
                    child: _icon('解锁控制', Icons.lock_open, () {
                      setState(() {
                        _locked = false;
                        _controlsVisible = true;
                      });
                      _scheduleHide();
                    }),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String formatTime(Duration time) {
  final seconds = time.inSeconds.clamp(0, 999999999);
  final minutes = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return seconds >= 3600
      ? '${seconds ~/ 3600}:$minutes:$rest'
      : '$minutes:$rest';
}
