import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'player_orientation.dart';
import '../../l10n/generated/app_localizations.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_theme.dart';
import '../../ui/tokens/app_semantic_colors.dart';
import '../../ui/tokens/app_motion.dart';
import '../../ui/components/media/playback_progress.dart';
import '../../ui/components/media/content_row.dart';
import '../../ui/icons/app_icons.dart';

import 'package:flutter/services.dart';
import 'package:openplayx_playback/playback.dart';

import '../../data/files/local_media_picker.dart';
import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_manager.dart';
import '../../services/library/library_service.dart';
import '../../data/sources/source_config.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    this.backend,
    this.onExit,
    this.onFileSelected,
    this.pickMedia = pickLocalMedia,
    this.sourceManager,
    this.libraryService,
  });
  final VoidCallback? onExit;
  final VoidCallback? onFileSelected;
  final PlayerBackend? backend;
  final SourceManager? sourceManager;
  final LibraryService? libraryService;
  final Future<LocalMedia?> Function() pickMedia;
  @override
  State<PlayerPage> createState() => PlayerPageState();
}

class PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  AppLocalizations get l => AppLocalizations.of(context);
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
        throw StateError('Player is closed');
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
        ShadToaster.of(
          context,
        ).show(ShadToast.destructive(description: Text(l.historySaveFailed)));
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
        ShadToaster.of(
          context,
        ).show(ShadToast.destructive(description: Text(l.historySaveFailed)));
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
      unawaited(_exitPlayback());
      return KeyEventResult.handled;
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

  final _orientationSession = PlayerOrientationSession();
  PlayerScreenOrientation _screenOrientation = PlayerScreenOrientation.system;
  int _videoQuarterTurns = 0;
  bool _changingDisplay = false;

  bool get _mobileDisplay =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  String get _displayLabel =>
      _mobileDisplay ? l.screenOrientation : l.videoRotation;

  Future<void> _showDisplayOptions() async {
    if (!_enabled || _changingDisplay) return;
    _endBoost();
    _panelOpened();
    try {
      final options = _mobileDisplay
          ? [l.orientationSystem, l.orientationPortrait, l.orientationLandscape]
          : [l.rotationOriginal, '90°', '180°', '270°'];
      final current = _mobileDisplay
          ? _screenOrientation.index
          : _videoQuarterTurns;
      final selected = await showShadDialog<int>(
        context: context,
        builder: (context) => ShadTheme(
          data: AppTheme.dark,
          child: ShadDialog(
            title: Text(_displayLabel),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < options.length; index++)
                  ShadButton.outline(
                    onPressed: () => Navigator.pop(context, index),
                    leading: current == index ? Icon(AppIcons.check) : null,
                    child: Text(options[index]),
                  ),
              ],
            ),
          ),
        ),
      );
      if (selected == null || !mounted || !_enabled) return;
      if (_mobileDisplay) {
        setState(() => _changingDisplay = true);
        final orientation = PlayerScreenOrientation.values[selected];
        if (await _adjust(() => _orientationSession.apply(orientation)) &&
            mounted) {
          setState(() => _screenOrientation = orientation);
        }
      } else {
        setState(() => _videoQuarterTurns = selected);
      }
    } finally {
      if (mounted) setState(() => _changingDisplay = false);
      _panelClosed();
    }
  }

  bool get _enabled =>
      _name != null &&
      !_busy &&
      !_closing &&
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
        ShadToaster.of(context)
            .show(ShadToast.destructive(description: Text(l.adjustFailed)));
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
    final id = await showShadSheet<int>(
      context: context,
      builder: (context) => ShadTheme(
        data: AppTheme.dark,
        child: ShadSheet(
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ContentRow(title: Text(l.audioTrack)),
                  if (tracks.isEmpty) ContentRow(title: Text(l.noAudioTracks)),
                  for (final track in tracks)
                    ContentRow(
                      title: Text(
                        track.name.isEmpty
                            ? l.numberedAudioTrack(track.id)
                            : track.name,
                      ),
                      subtitle: track.language == null
                          ? null
                          : Text(track.language!),
                      trailing: _selectedAudioTrack == track.id
                          ? Icon(AppIcons.check)
                          : null,
                      onTap: () => Navigator.pop(context, track.id),
                    ),
                ],
              ),
            ),
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
          _error = l.playbackCommandFailed;
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
      widget.onFileSelected?.call();
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
      if (mounted) setState(() => _error = l.openFileFailed);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scheduleHide();
      }
    }
  }

  Future<void>? _openingMedia;
  bool _closing = false;

  Future<void> openFile() {
    if (_closing || _busy) return Future.value();
    return _openingMedia = _open();
  }

  Future<void> _exitPlayback() async {
    if (widget.onExit != null) {
      widget.onExit!();
    } else if (await stopPlayback() && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<bool> stopPlayback() async {
    if (_closing) return false;
    _closing = true;
    _endBoost();
    try {
      await _openingMedia;
      await _speedCommands;
      if (!mounted) return false;
      _checkpoint(force: true);
      await _backend.stop();
      await _adjust(_orientationSession.restore);
      _finishTracking();
      final stream = _stream;
      _stream = null;
      await stream?.release();
      if (!mounted) return false;
      _hideTimer?.cancel();
      setState(() {
        _name = null;
        _error = null;
        _drag = null;
        _locked = false;
        _videoQuarterTurns = 0;
        _screenOrientation = PlayerScreenOrientation.system;
        _controlsVisible = true;
      });
      return true;
    } catch (_) {
      if (mounted) {
        ShadToaster.of(
          context,
        ).show(ShadToast.destructive(description: Text(l.stopPlaybackFailed)));
      }
      return false;
    } finally {
      _closing = false;
    }
  }

  Future<void> playSelection(SourceSelection selection) {
    if (_closing || _busy) return selection.stream.release();
    return _openingMedia = _playSelection(selection);
  }

  Future<void> _playSelection(SourceSelection selection) async {
    if (!mounted) {
      await selection.stream.release();
      return;
    }
    _endBoost();
    await _speedCommands;
    if (!mounted) {
      await selection.stream.release();
      return;
    }
    setState(() => _busy = true);
    try {
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
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scheduleHide();
      }
    }
  }

  @override
  void dispose() {
    unawaited(
      _orientationSession.restore().catchError((Object error) {
        debugPrint('Could not restore screen orientation: $error');
      }),
    );
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
    _hideTimer = Timer(Duration(seconds: 3), () {
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
    final slider = ShadSliderController(
      initialValue: volume
          ? _backend.value.volume.clamp(0, 100).toDouble()
          : _brightness * 100,
    );
    void syncVolume() {
      if (volume) slider.value = _backend.value.volume.clamp(0, 100).toDouble();
    }

    _backend.addListener(syncVolume);
    _panelOpened();
    try {
      await showShadDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (context) => ShadTheme(
          data: AppTheme.dark,
          child: ShadDialog(
            alignment: Alignment.bottomRight,
            constraints: BoxConstraints(maxWidth: 320),
            child: SizedBox(
              width: 280,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                                        ? AppIcons.volume
                                        : AppIcons.brightness,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(volume ? l.volume : l.brightness),
                                  Spacer(),
                                  Text('${level.round()}%'),
                                ],
                              ),
                              ShadSlider(
                                key: Key(
                                  volume
                                      ? 'playback-volume'
                                      : 'playback-brightness',
                                ),
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
                                controller: slider,
                                enabled: _enabled,
                              ),
                            ],
                          );
                        },
                      ),
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      _backend.removeListener(syncVolume);
      slider.dispose();
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
          duration: AppMotion.duration(context, AppMotion.feedback),
          child: child,
        ),
      ),
    ),
  );

  Widget _icon(String tooltip, IconData icon, VoidCallback? action) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      child: ShadIconButton.ghost(
        onPressed: action,
        enabled: action != null,
        icon: Icon(icon, size: 20),
        width: 48,
        height: 48,
        foregroundColor: AppSemanticColors.playerForeground,
      ),
    ),
  );

  Widget _transport(PlayerSnapshot value) {
    final seekable =
        _enabled && value.canSeek && value.duration > Duration.zero;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _icon(l.rewind, AppIcons.rewind, seekable ? () => _skip(-10) : null),
        _icon(
          value.status == PlaybackStatus.playing ? l.pause : l.play,
          value.status == PlaybackStatus.playing
              ? AppIcons.pause
              : AppIcons.play,
          _enabled ? _togglePlayback : null,
        ),
        _icon(l.forward, AppIcons.forward, seekable ? () => _skip(10) : null),
      ],
    );
  }

  Widget _speedMenu() => Tooltip(
    message: l.playbackSpeed,
    child: ShadButton.ghost(
      enabled: _enabled,
      width: 48,
      height: 48,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 48,
        child: Center(
          child: FittedBox(fit: BoxFit.scaleDown, child: Text('$_speed×')),
        ),
      ),
      onPressed: () async {
        _panelOpened();
        try {
          final speed = await showShadDialog<double>(
            context: context,
            builder: (context) => ShadTheme(
              data: AppTheme.dark,
              child: ShadDialog(
                title: Text(l.playbackSpeed),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                      ShadButton.outline(
                        onPressed: () => Navigator.pop(context, speed),
                        leading: speed == _speed ? Icon(AppIcons.check) : null,
                        child: Text('$speed×'),
                      ),
                  ],
                ),
              ),
            ),
          );
          if (speed == null) return;
          await _speedCommands;
          if (!mounted || !_enabled) return;
          if (await _adjust(() => _backend.setSpeed(speed))) {
            if (mounted) setState(() => _speed = speed);
          }
        } finally {
          _panelClosed();
        }
      },
    ),
  );

  Widget _moreMenu() => _icon(
    l.morePlaybackSettings,
    AppIcons.more,
    !_enabled
        ? null
        : () async {
            _panelOpened();
            String? action;
            try {
              action = await showShadDialog<String>(
                context: context,
                builder: (context) => ShadTheme(
                  data: AppTheme.dark,
                  child: ShadDialog(
                    title: Text(l.morePlaybackSettings),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in {
                          'display': _displayLabel,
                          'audio': l.audioTrack,
                          'brightness': l.brightness,
                          'lock': l.lockControls,
                        }.entries)
                          ShadButton.ghost(
                            onPressed: () => Navigator.pop(context, item.key),
                            child: Text(item.value),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            } finally {
              _panelClosed();
            }
            if (!mounted) return;
            switch (action) {
              case 'display':
                await _showDisplayOptions();
              case 'audio':
                await _showAudioTracks();
              case 'brightness':
                await _showLevel(false);
              case 'lock':
                _lock();
            }
          },
  );

  Widget _bottomControls(PlayerSnapshot value) {
    final duration = value.duration.inMilliseconds.toDouble();
    final position = (_drag ?? value.position.inMilliseconds.toDouble()).clamp(
      0.0,
      duration > 0 ? duration : 1.0,
    );
    final seekable = _enabled && value.canSeek && duration > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, AppSemanticColors.playerOverlay],
        ),
      ),
      child: Padding(
        key: Key('player-control-bar'),
        padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final remaining = l.remainingTime(
                  formatTime(
                    Duration(milliseconds: (duration - position).round()),
                  ),
                );
                return Row(
                  children: [
                    Flexible(
                      child: Tooltip(
                        message: remaining,
                        child: Text(
                          '${formatTime(Duration(milliseconds: position.round()))} / ${duration > 0 ? formatTime(value.duration) : '--:--'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.dark.textTheme.muted.copyWith(
                            color: AppSemanticColors.playerMuted,
                          ),
                        ),
                      ),
                    ),
                    Spacer(),
                    Flexible(
                      child: Text(
                        l.readSpeed(
                          value.readSpeedMBps == null
                              ? '--'
                              : value.readSpeedMBps!.toStringAsFixed(2),
                        ),
                        key: Key('playback-read-speed'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.dark.textTheme.muted.copyWith(
                          color: AppSemanticColors.playerMuted,
                        ),
                      ),
                    ),
                    if (duration > 0 && constraints.maxWidth >= 456) ...[
                      SizedBox(width: 16),
                      Text(
                        remaining,
                        style: AppTheme.dark.textTheme.muted.copyWith(
                          color: AppSemanticColors.playerMuted,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            PlaybackProgress(
              key: const Key('playback-progress'),
              value: position,
              max: duration > 0 ? duration : 1,
              enabled: seekable,
              label: l.playbackPosition,
              onPreview: (value) => setState(() => _drag = value),
              onCommit: (value) async {
                await _command(
                  () => _backend.seek(Duration(milliseconds: value.round())),
                );
                if (mounted) setState(() => _drag = null);
                _scheduleHide();
              },
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 560;
                return Row(
                  children: [
                    _transport(value),
                    Spacer(),
                    _speedMenu(),
                    _icon(
                      l.playerVolume,
                      value.volume == 0 ? AppIcons.muted : AppIcons.volume,
                      _enabled ? () => _showLevel(true) : null,
                    ),
                    if (wide) ...[
                      _icon(
                        _displayLabel,
                        _mobileDisplay
                            ? AppIcons.screenOrientation
                            : AppIcons.rotateVideo,
                        _enabled && !_changingDisplay
                            ? _showDisplayOptions
                            : null,
                      ),
                      _icon(
                        l.brightness,
                        AppIcons.brightness,
                        _enabled ? () => _showLevel(false) : null,
                      ),
                      _icon(
                        l.audioTrack,
                        AppIcons.audio,
                        _enabled ? _showAudioTracks : null,
                      ),
                      _icon(
                        l.lockControls,
                        AppIcons.lock,
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
  Widget build(BuildContext context) => ShadTheme(
    data: AppTheme.dark,
    child: Focus(
      focusNode: _playerFocus,
      autofocus: true,
      onKeyEvent: _handlePlayerKey,
      child: Scaffold(
        backgroundColor: AppSemanticColors.playerSurface,
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
                    key: Key('video-gestures'),
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
                        IgnorePointer(
                          child: RotatedBox(
                            key: const Key('video-rotation'),
                            quarterTurns: _videoQuarterTurns,
                            child: PlayerVideoView(backend: _backend),
                          ),
                        ),
                        IgnorePointer(
                          child: ColoredBox(
                            key: Key('video-dimming'),
                            color: AppSemanticColors.playerSurface.withValues(
                              alpha: (1 - _brightness) * 0.85,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_name == null)
                    IgnorePointer(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                AppIcons.playMedia,
                                size: 56,
                                color: AppSemanticColors.playerMuted,
                              ),
                              SizedBox(height: 12),
                              Text(
                                l.playerEmpty,
                                style: AppTheme.dark.textTheme.large.copyWith(
                                  color: AppSemanticColors.playerMuted,
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppSemanticColors.playerScrim,
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              _icon(
                                l.back,
                                AppIcons.back,
                                _closing ? null : _exitPlayback,
                              ),
                              Expanded(
                                child: Text(
                                  _name ?? 'OpenPlayX',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.dark.textTheme.small.copyWith(
                                    color: AppSemanticColors.playerMuted,
                                  ),
                                ),
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
                          builder: (context, value, _) =>
                              _bottomControls(value),
                        ),
                      ),
                    ),
                  if (_busy || _backend.value.status == PlaybackStatus.opening)
                    IgnorePointer(
                      child: Center(
                        child: SizedBox(
                          width: 120,
                          child: ShadProgress(semanticsLabel: l.loading),
                        ),
                      ),
                    ),
                  if (_error != null ||
                      _backend.value.status == PlaybackStatus.error)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          _error ?? l.playbackFailed,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  if (_boosting)
                    Positioned(
                      top: 64,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Center(child: ShadBadge(child: Text(l.boost))),
                      ),
                    ),
                  if (_locked)
                    Positioned(
                      top: 8,
                      left: 12,
                      child: _icon(l.unlockControls, AppIcons.unlock, () {
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
