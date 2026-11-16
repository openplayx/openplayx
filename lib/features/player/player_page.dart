import '../../app/diagnostics/diagnostics_bootstrap.dart';
import '../../app/diagnostics/diagnostics_service.dart';

import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:path_provider/path_provider.dart';

import 'player_extras.dart';
import 'player_keymap.dart';
import 'player_orientation.dart';
import 'player_widgets.dart';
import 'video_frame.dart';
import 'window_fullscreen.dart';
import '../../l10n/generated/app_localizations.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/system_ui.dart';
import '../../ui/tokens/app_semantic_colors.dart';
import '../../ui/tokens/app_motion.dart';
import '../../ui/icons/app_icons.dart';

import 'package:flutter/services.dart';
import 'package:openplayx_playback/playback.dart';

import '../../data/files/local_media_picker.dart';
import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_manager.dart';
import '../../services/library/library_service.dart';
import '../../services/subtitles/recognized_subtitles.dart';
import '../../data/sources/source_config.dart';
import '../../ui/components/feedback/app_feedback.dart';

part 'player_desktop.dart';
part 'player_mobile.dart';
part 'player_panels.dart';

/// Panels and sheets the player shows over the video (design §3.5, §4.4).
enum PlayerPanel {
  none,
  tracks,
  speed,
  settings,
  more,
  sleep,
  bookmarks,
  frame,
  sync,
  info,
  help,
}

/// Desktop "设置与效果" side panel tabs.
enum SettingsTab { picture, sync, info }

/// Transient gesture feedback on mobile (design §4.3).
enum _Feedback { none, seek, volume, brightness }

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    this.backend,
    this.onExit,
    this.onFileSelected,
    this.showBack = true,
    this.pickMedia = pickLocalMedia,
    this.pickSubtitle = pickSubtitleFile,
    this.sourceManager,
    this.libraryService,
    this.active = true,
    this.prefs = const PlayerPrefs(),
    this.fullscreen,
  });
  final VoidCallback? onExit;

  /// Whether the player is on screen. The app shell keeps the player mounted
  /// (offstage) while the user browses, so phone immersive mode follows this
  /// flag rather than the widget's lifetime.
  final bool active;
  final VoidCallback? onFileSelected;

  /// False in a dedicated player window, which is closed with its own
  /// window controls instead of navigating back.
  final bool showBack;
  final PlayerBackend? backend;
  final SourceManager? sourceManager;
  final LibraryService? libraryService;
  final Future<LocalMedia?> Function() pickMedia;
  final Future<Uri?> Function() pickSubtitle;
  final PlayerPrefs prefs;
  final WindowFullscreen? fullscreen;
  @override
  State<PlayerPage> createState() => PlayerPageState();
}

class PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  AppLocalizations get l => AppLocalizations.of(context);
  PlayerPrefs get _prefs => widget.prefs;
  late final PlayerBackend _backend;
  late final SourceManager _sources;
  late final WindowFullscreen _window;
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
        showAppToast(context, l.historySaveFailed, kind: FeedbackKind.error);
      }
    }
  }

  void _finishTracking() {
    _checkpoint(force: true);
    _trackingGeneration++;
    _currentRef = null;
    _selectedRecognized = null;
    _recognizedTracks.clear();
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
    _currentRef = ref;
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
      final title = service.metadata.fields(media)['title']?.toString().trim();
      if (mounted && title != null && title.isNotEmpty) {
        setState(() => _displayTitle = title);
      }
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
        showAppToast(context, l.historySaveFailed, kind: FeedbackKind.error);
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
  // Scraped/edited library title, preferred over the file name in the header.
  String? _displayTitle;
  String? _error;
  bool _busy = false;
  bool _background = false;
  double? _drag;
  Timer? _hideTimer;

  /// Whether the overlay controls are shown; the shell fades the assistant
  /// button with them.
  final controlsVisibility = ValueNotifier(true);
  bool get _controlsVisible => controlsVisibility.value;
  set _controlsVisible(bool value) => controlsVisibility.value = value;
  bool _pointerDown = false;
  bool _hoveringControls = false;
  int _openPanels = 0;
  PlaybackStatus _lastStatus = PlaybackStatus.idle;
  bool _locked = false;
  bool _boosting = false;
  double _speed = 1;
  double _brightness = 1;
  int? _selectedAudioTrack;
  // null: the media's default; -1: subtitles switched off by the user.
  int? _selectedSubtitleTrack;
  // Resource being played (for saved recognised subtitles of this version).
  ResourceRef? _currentRef;
  // Recognised subtitle loaded and selected now (binding id), if any.
  String? _selectedRecognized;
  // binding id → player track id once loaded, so a re-select does not add
  // the same file twice and the loaded copy is not listed as embedded.
  final _recognizedTracks = <String, int>{};
  Future<void> _speedCommands = Future.value();

  final _playerFocus = FocusNode(debugLabel: 'player-keyboard');
  int _volumeBeforeMute = 100;

  // ---- Design v0.2 state -------------------------------------------------
  PlayerPanel _panel = PlayerPanel.none;
  SettingsTab _settingsTab = SettingsTab.picture;
  bool _showRemaining = false;
  final _tracksButtonKey = GlobalKey();
  final _speedButtonKey = GlobalKey();
  bool _fullscreen = false;
  bool _repeatOne = false;
  bool _statsOverlay = false;
  bool _advancedTools = false;
  AbLoop _ab = const AbLoop();
  final _bookmarks = <PlayerBookmark>[];
  final _quickBookmarks = <int, Duration>{};
  Duration _audioDelay = Duration.zero;
  Duration _subtitleDelay = Duration.zero;
  VideoFrameSettings _frame = const VideoFrameSettings();
  DateTime? _sleepAt;
  bool _sleepAtEnd = false;
  Timer? _sleepTimer;
  Timer? _clockTimer;
  ({IconData? icon, String text, String? detail})? _osd;
  Timer? _osdTimer;
  List<PlayerAudioTrack> _audioTracks = const [];
  List<PlayerSubtitleTrack> _subtitleTracks = const [];
  List<RecognizedSubtitle> _recognized = const [];
  PlayerMediaInfo? _mediaInfo;
  PlayerStats? _stats;
  Timer? _statsTimer;
  final _gestures = _MobileGestures();
  Timer? _tapSeekTimer;
  Timer? _feedbackTimer;
  Timer? _unlockTimer;
  bool _showUnlock = false;

  bool get _mobileDisplay =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  String get _displayLabel =>
      _mobileDisplay ? l.screenOrientation : l.videoRotation;

  // ---- Keyboard (design §6) ---------------------------------------------

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
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      if (_panel != PlayerPanel.none) {
        _closePanel();
      } else if (_locked) {
        _unlock();
      } else if (_fullscreen) {
        unawaited(_setFullscreen(false));
      } else {
        unawaited(_exitPlayback());
      }
      return KeyEventResult.handled;
    }
    final keyboard = HardwareKeyboard.instance;
    final apple = isApplePlatform;
    final command = resolvePlayerKey(
      key,
      shift: keyboard.isShiftPressed,
      alt: keyboard.isAltPressed,
      primary: apple ? keyboard.isMetaPressed : keyboard.isControlPressed,
      otherModifier: apple ? keyboard.isControlPressed : keyboard.isMetaPressed,
    );
    if (command == null) return KeyEventResult.ignored;
    // An open panel keeps arrows and letters for itself; Escape closes it.
    if (_panel != PlayerPanel.none) return KeyEventResult.ignored;
    final action = command.action;
    if (action == PlayerAction.openFile) {
      if (event is! KeyRepeatEvent) unawaited(openFile());
      return KeyEventResult.handled;
    }
    if (_locked || !_enabled) return KeyEventResult.handled;
    if (event is KeyRepeatEvent &&
        (command.bookmarkSlot != null ||
            (action != null && isTogglePlayerAction(action)))) {
      return KeyEventResult.handled;
    }
    if (command.bookmarkSlot != null) {
      _quickBookmark(command.bookmarkSlot!, set: command.setBookmark == true);
    } else if (action == PlayerAction.toggleControls) {
      _toggleControls();
      return KeyEventResult.handled;
    } else {
      _showControls();
      unawaited(_perform(action!));
    }
    return KeyEventResult.handled;
  }

  /// Runs one player command; shared by keys, menus, buttons and gestures.
  Future<void> _perform(PlayerAction action) async {
    if (!_enabled && action != PlayerAction.openFile) return;
    switch (action) {
      case PlayerAction.togglePlay:
        _togglePlayback();
      case PlayerAction.stop:
        await _stopToStart();
      case PlayerAction.toggleFullscreen:
        await _setFullscreen(!_fullscreen);
      case PlayerAction.jumpBackExtraShort:
        _jump(-_prefs.extraShortJump);
      case PlayerAction.jumpForwardExtraShort:
        _jump(_prefs.extraShortJump);
      case PlayerAction.jumpBackShort:
        _jump(-_prefs.shortJump);
      case PlayerAction.jumpForwardShort:
        _jump(_prefs.shortJump);
      case PlayerAction.jumpBackMedium:
        _jump(-_prefs.mediumJump);
      case PlayerAction.jumpForwardMedium:
        _jump(_prefs.mediumJump);
      case PlayerAction.jumpBackLong:
        _jump(-_prefs.longJump);
      case PlayerAction.jumpForwardLong:
        _jump(_prefs.longJump);
      case PlayerAction.faster:
        await _setSpeed(nextSpeedPreset(_speed, faster: true));
      case PlayerAction.slower:
        await _setSpeed(nextSpeedPreset(_speed, faster: false));
      case PlayerAction.fasterFine:
        await _setSpeed(clampSpeed(_speed + fineSpeedStep));
      case PlayerAction.slowerFine:
        await _setSpeed(clampSpeed(_speed - fineSpeedStep));
      case PlayerAction.normalSpeed:
        await _setSpeed(1);
      case PlayerAction.showPosition:
        final value = _backend.value;
        _flash(
          AppIcons.clock,
          '${formatTime(value.position)} / ${value.duration > Duration.zero ? formatTime(value.duration) : '--:--'}',
        );
      case PlayerAction.jumpToTime:
        await _askJumpToTime();
      case PlayerAction.volumeUp:
        await _setVolume(_backend.value.volume + _prefs.volumeStep);
      case PlayerAction.volumeDown:
        await _setVolume(_backend.value.volume - _prefs.volumeStep);
      case PlayerAction.mute:
        await _toggleMute();
      case PlayerAction.nextAudioTrack:
        await _cycleAudioTrack();
      case PlayerAction.nextSubtitle:
        await _cycleSubtitle(1);
      case PlayerAction.previousSubtitle:
        await _cycleSubtitle(-1);
      case PlayerAction.toggleSubtitles:
        await _toggleSubtitles();
      case PlayerAction.subtitleDelayUp:
        await _setSubtitleDelay(_subtitleDelay + _prefs.delayStep);
      case PlayerAction.subtitleDelayDown:
        await _setSubtitleDelay(_subtitleDelay - _prefs.delayStep);
      case PlayerAction.audioDelayUp:
        await _setAudioDelay(_audioDelay + _prefs.delayStep);
      case PlayerAction.audioDelayDown:
        await _setAudioDelay(_audioDelay - _prefs.delayStep);
      case PlayerAction.cycleAspectRatio:
        _setFrame(
          _frame.copyWith(
            aspectIndex: (_frame.aspectIndex + 1) % videoAspectRatios.length,
          ),
        );
      case PlayerAction.cycleZoom:
        _setFrame(_frame.copyWith(zoom: nextZoomStep(_frame.zoom)));
      case PlayerAction.cycleZoomReverse:
        _setFrame(
          _frame.copyWith(zoom: nextZoomStep(_frame.zoom, reverse: true)),
        );
      case PlayerAction.cycleFitMode:
        _setFrame(
          _frame.copyWith(
            mode: VideoFitMode
                .values[(_frame.mode.index + 1) % VideoFitMode.values.length],
          ),
        );
      case PlayerAction.toggleControls:
        _toggleControls();
      case PlayerAction.snapshot:
        await _snapshot();
      case PlayerAction.cycleRepeat:
        setState(() => _repeatOne = !_repeatOne);
        _flash(
          _repeatOne ? AppIcons.repeatOne : AppIcons.repeat,
          _repeatOne ? l.plRepeatOne : l.plRepeatOff,
        );
      case PlayerAction.openFile:
        await openFile();
      case PlayerAction.shortcutHelp:
        _openPanel(PlayerPanel.help);
    }
  }

  void _togglePlayback() {
    if (!_enabled) return;
    _endBoost();
    // A seek made while paused is confirmed only once playback resumes.
    if (_pendingSeek != null) _pendingSeekAt = DateTime.now();
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

  bool get _seekable {
    final value = _backend.value;
    return _enabled && value.canSeek && value.duration > Duration.zero;
  }

  Future<bool> _adjust(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (error, stack) {
      debugPrint('Player adjustment failed: $error\n$stack');
      if (mounted) {
        showAppToast(context, l.adjustFailed, kind: FeedbackKind.error);
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

  Future<void> _setSpeed(double speed) async {
    speed = clampSpeed(speed);
    await _speedCommands;
    if (!mounted || !_enabled) return;
    if (await _adjust(() => _backend.setSpeed(speed)) && mounted) {
      setState(() => _speed = speed);
      _flash(AppIcons.speed, formatSpeed(speed));
    }
  }

  void _startBoost() {
    if (!_enabled || _backend.value.status != PlaybackStatus.playing) return;
    _hideTimer?.cancel();
    setState(() => _boosting = true);
    unawaited(_applySpeed(boostSpeed(_speed)));
    HapticFeedback.selectionClick();
  }

  /// Swipe up during a long press keeps the boost speed (design MG10).
  void _lockBoost() {
    if (!_boosting) return;
    final speed = boostSpeed(_speed);
    setState(() {
      _boosting = false;
      _speed = speed;
    });
    unawaited(_applySpeed(speed));
    HapticFeedback.mediumImpact();
    _flash(AppIcons.speed, l.plSpeedLocked(formatSpeed(speed)));
    _scheduleHide();
  }

  void _endBoost() {
    if (!_boosting) return;
    setState(() => _boosting = false);
    unawaited(_applySpeed(_speed));
    _scheduleHide();
  }

  void _skip(int seconds) => _jump(Duration(seconds: seconds));

  /// Target of the last seek until the player reports it. Native position
  /// events lag a seek, so repeated jumps and the seek bar build on this
  /// instead of the stale position.
  Duration? _pendingSeek;
  DateTime? _pendingSeekAt;

  /// Start position and every target of the current chain of quick seeks;
  /// reports near any of them belong to the chain.
  final _pendingSeekChain = <Duration>[];

  Duration get _position {
    final pending = _pendingSeek;
    if (pending != null && !_pendingSeekExpired) return pending;
    return _backend.value.position;
  }

  /// A pending target expires after 2 s of playback without confirmation;
  /// while paused VLCKit reports no new time, so it stays until playback.
  bool get _pendingSeekExpired =>
      _pendingSeekAt == null ||
      (_backend.value.status != PlaybackStatus.paused &&
          DateTime.now().difference(_pendingSeekAt!) >
              const Duration(seconds: 2));

  /// Absolute seek through the shared path (keys, bar, gestures, menus).
  Future<void> _seekAbsolute(Duration target) async {
    final max = _backend.value.duration;
    if (target.isNegative) target = Duration.zero;
    if (max > Duration.zero && target > max) target = max;
    if (_backend.value.status == PlaybackStatus.ended) {
      // VLC ignores seeks after the end: restart, then continue from the
      // target once the media plays again (same path as resuming history).
      _resume = target;
      _pendingSeek = target;
      _pendingSeekChain
        ..clear()
        ..add(_backend.value.position)
        ..add(target);
      _pendingSeekAt = DateTime.now();
      await _command(_backend.play);
      return;
    }
    if (_pendingSeek == null) {
      _pendingSeekChain
        ..clear()
        ..add(_backend.value.position);
    }
    _pendingSeekChain.add(target);
    _pendingSeek = target;
    _pendingSeekAt = DateTime.now();
    return _command(() => _backend.seek(target));
  }

  /// Relative seek with OSD feedback; clamps to the media.
  void _jump(Duration delta, {bool feedback = true}) {
    final value = _backend.value;
    if (!_seekable) return;
    final target = (_position + delta).inMilliseconds.clamp(
      0,
      value.duration.inMilliseconds,
    );
    unawaited(_seekAbsolute(Duration(milliseconds: target)));
    if (feedback) {
      final seconds = delta.inSeconds;
      _flash(
        seconds < 0 ? AppIcons.rewindOsd : AppIcons.forwardOsd,
        l.plJumpSeconds('${seconds > 0 ? '+' : ''}$seconds'),
        detail: formatTime(Duration(milliseconds: target)),
      );
    }
  }

  void _seekTo(Duration position) {
    if (!_seekable) return;
    unawaited(_seekAbsolute(position));
  }

  Future<void> _setVolume(int volume) async {
    volume = volume.clamp(0, 100);
    if (await _adjust(() => _backend.setVolume(volume))) {
      _flash(volume == 0 ? AppIcons.muted : AppIcons.volume, '$volume%');
    }
  }

  Future<void> _toggleMute() async {
    final volume = _backend.value.volume;
    if (volume > 0) _volumeBeforeMute = volume.clamp(1, 100);
    final next = volume == 0 ? _volumeBeforeMute : 0;
    if (await _adjust(() => _backend.setVolume(next))) {
      _flash(
        next == 0 ? AppIcons.muted : AppIcons.volume,
        next == 0 ? l.plMuted : '$next%',
      );
    }
  }

  Future<void> _setAudioDelay(Duration delay) async {
    if (!_backend.supportsDelays) return;
    if (await _adjust(() => _backend.setAudioDelay(delay)) && mounted) {
      setState(() => _audioDelay = delay);
      _flash(AppIcons.audio, '${l.plAudioDelay} ${formatDelay(delay)}');
    }
  }

  Future<void> _setSubtitleDelay(Duration delay) async {
    if (!_backend.supportsDelays) return;
    if (await _adjust(() => _backend.setSubtitleDelay(delay)) && mounted) {
      setState(() => _subtitleDelay = delay);
      _flash(AppIcons.captions, '${l.plSubtitleDelay} ${formatDelay(delay)}');
    }
  }

  void _setFrame(VideoFrameSettings frame) {
    setState(() => _frame = frame);
    final aspect = videoAspectLabels[frame.aspectIndex] ?? l.plAspectDefault;
    _flash(
      AppIcons.aspect,
      '${_fitLabel(frame.mode)} · $aspect'
      '${frame.zoom == 1 ? '' : ' · ${_zoomLabel(frame.zoom)}'}',
    );
  }

  String _fitLabel(VideoFitMode mode) => switch (mode) {
    VideoFitMode.fit => l.plFitBest,
    VideoFitMode.fill => l.plFitFill,
    VideoFitMode.original => l.plFitOriginal,
  };

  String _zoomLabel(double zoom) => switch (zoom) {
    0.25 => '1/4',
    0.5 => '1/2',
    1.0 => l.plZoomOriginal,
    2.0 => '2×',
    _ => '${(zoom * 100).round()}%',
  };

  Future<void> _stopToStart() async {
    if (!_seekable) {
      await _command(_backend.pause);
      return;
    }
    await _command(_backend.pause);
    await _command(() => _backend.seek(Duration.zero));
    _flash(AppIcons.stop, l.plStop);
  }

  Future<void> _setFullscreen(bool value) async {
    if (_mobileDisplay || !_window.isSupported) return;
    final result = await _window.setFullscreen(value);
    if (mounted) setState(() => _fullscreen = result);
  }

  void _quickBookmark(int slot, {required bool set}) {
    if (set) {
      _quickBookmarks[slot] = _backend.value.position;
      _flash(AppIcons.bookmark, l.plQuickBookmarkSet('${slot + 1}'));
    } else if (_quickBookmarks[slot] != null) {
      _seekTo(_quickBookmarks[slot]!);
      _flash(AppIcons.bookmark, formatTime(_quickBookmarks[slot]!));
    }
  }

  void _addBookmark() {
    final position = _position;
    setState(() {
      _bookmarks
        ..removeWhere((b) => (b.position - position).inSeconds.abs() < 1)
        ..add(PlayerBookmark(position))
        ..sort((a, b) => a.position.compareTo(b.position));
    });
    _flash(AppIcons.bookmark, l.plBookmarkAdded(formatTime(position)));
  }

  void _advanceAb() {
    if (!_seekable) return;
    setState(() => _ab = _ab.advance(_position));
    _flash(AppIcons.repeatOne, switch (_ab.phase) {
      AbPhase.off => l.plAbCleared,
      AbPhase.aSet => l.plAbASet(formatTime(_ab.a!)),
      AbPhase.looping => l.plAbLooping(formatTime(_ab.a!), formatTime(_ab.b!)),
    });
  }

  void _setSleep(int? minutes) {
    _sleepTimer?.cancel();
    setState(() {
      _sleepAt = null;
      _sleepAtEnd = false;
      if (minutes == -1) {
        _sleepAtEnd = true;
      } else if (minutes != null) {
        _sleepAt = DateTime.now().add(Duration(minutes: minutes));
        _sleepTimer = Timer(Duration(minutes: minutes), _sleepNow);
      }
    });
    _ensureClock();
  }

  void _sleepNow() {
    if (!mounted) return;
    setState(() {
      _sleepAt = null;
      _sleepAtEnd = false;
    });
    unawaited(_command(_backend.pause));
    showAppToast(context, l.plSleepFinished);
  }

  /// Refreshes the sleep countdown chip once a second while it is shown.
  void _ensureClock() {
    final needed = _sleepAt != null;
    if (needed && _clockTimer == null) {
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needed) {
      _clockTimer?.cancel();
      _clockTimer = null;
    }
  }

  Future<void> _snapshot() async {
    final status = _backend.value.status;
    if (!_backend.supportsSnapshot || !_enabled) return;
    if (status != PlaybackStatus.playing && status != PlaybackStatus.paused) {
      // Nothing is on screen after the end; native snapshots would fail.
      showAppToast(context, l.plSnapshotFailed, kind: FeedbackKind.error);
      return;
    }
    try {
      final bytes = await _backend.takeSnapshot();
      final directory = _mobileDisplay
          ? Directory(
              '${(await getApplicationDocumentsDirectory()).path}/Screenshots',
            )
          : (await getDownloadsDirectory() ??
                await getApplicationDocumentsDirectory());
      await directory.create(recursive: true);
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-')
          .substring(0, 19);
      final base = (_displayTitle ?? _name ?? 'OpenPlayX')
          .replaceFirst(RegExp(r'\.[A-Za-z0-9]{2,4}$'), '')
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${directory.path}/$base-$stamp.png');
      await file.writeAsBytes(bytes);
      if (mounted) {
        HapticFeedback.mediumImpact();
        showAppToast(context, l.plSnapshotSaved(file.path));
      }
    } catch (error, stack) {
      debugPrint('Snapshot failed: $error\n$stack');
      if (mounted) {
        showAppToast(context, l.plSnapshotFailed, kind: FeedbackKind.error);
      }
    }
  }

  void _flash(IconData? icon, String text, {String? detail}) {
    if (!mounted) return;
    _osdTimer?.cancel();
    setState(() => _osd = (icon: icon, text: text, detail: detail));
    _osdTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _osd = null);
    });
  }

  // ---- Tracks ------------------------------------------------------------

  Future<void> _loadTracks() async {
    List<PlayerAudioTrack> audio = const [];
    List<PlayerSubtitleTrack> subtitles = const [];
    try {
      audio = await _backend.getAudioTracks();
      subtitles = await _backend.getSubtitleTracks();
    } catch (error) {
      debugPrint('Track listing failed: $error');
      return;
    }
    final recognized = await _recognizedSubtitles();
    if (!mounted) return;
    final loaded = _recognizedTracks.values.toSet();
    setState(() {
      _audioTracks = audio;
      // Loaded recognised files show up as player tracks too; list them once.
      _subtitleTracks = [
        for (final t in subtitles)
          if (!loaded.contains(t.id)) t,
      ];
      _recognized = recognized;
    });
  }

  String _audioName(PlayerAudioTrack track) =>
      track.name.isEmpty ? l.numberedAudioTrack(track.id) : track.name;
  String _subtitleName(PlayerSubtitleTrack track) =>
      track.name.isEmpty ? l.numberedSubtitleTrack(track.id) : track.name;

  Future<void> _selectAudio(int id) async {
    if (!_enabled) return;
    if (await _adjust(() => _backend.setAudioTrack(id)) && mounted) {
      setState(() => _selectedAudioTrack = id);
      final track = _audioTracks.where((t) => t.id == id).firstOrNull;
      _flash(AppIcons.audio, track == null ? l.audioTrack : _audioName(track));
    }
  }

  Future<void> _selectSubtitle(int id) async {
    if (!_enabled) return;
    if (await _adjust(
      () => id < 0 ? _backend.disableSubtitle() : _backend.setSubtitleTrack(id),
    )) {
      if (!mounted) return;
      setState(() {
        _selectedSubtitleTrack = id;
        _selectedRecognized = null;
      });
      final track = _subtitleTracks.where((t) => t.id == id).firstOrNull;
      _flash(
        AppIcons.captions,
        id < 0
            ? l.subtitleOff
            : track == null
            ? l.subtitleTrack
            : _subtitleName(track),
      );
    }
  }

  Future<void> _cycleAudioTrack() async {
    await _loadTracks();
    if (_audioTracks.isEmpty) {
      _flash(AppIcons.audio, l.noAudioTracks);
      return;
    }
    final index = _audioTracks.indexWhere((t) => t.id == _selectedAudioTrack);
    await _selectAudio(_audioTracks[(index + 1) % _audioTracks.length].id);
  }

  Future<void> _cycleSubtitle(int direction) async {
    await _loadTracks();
    if (_subtitleTracks.isEmpty) {
      _flash(AppIcons.captions, l.noSubtitleTracks);
      return;
    }
    // "Off" is the extra slot before the first track.
    final ids = [-1, for (final t in _subtitleTracks) t.id];
    var index = ids.indexOf(_selectedSubtitleTrack ?? ids[1]);
    if (index < 0) index = 0;
    await _selectSubtitle(ids[(index + direction) % ids.length]);
  }

  Future<void> _toggleSubtitles() async {
    if (_selectedSubtitleTrack == -1) {
      await _loadTracks();
      if (_subtitleTracks.isNotEmpty) {
        await _selectSubtitle(_subtitleTracks.first.id);
      }
    } else {
      await _selectSubtitle(-1);
    }
  }

  Future<void> _addSubtitleFile() async {
    if (!_backend.supportsExternalSubtitles || !_enabled) return;
    _panelOpened();
    Uri? uri;
    try {
      uri = await widget.pickSubtitle();
    } catch (error) {
      debugPrint('Subtitle selection failed: $error');
    } finally {
      _panelClosed();
    }
    if (uri == null || !mounted) return;
    if (await _adjust(() => _backend.addExternalSubtitle(uri!))) {
      _flash(AppIcons.captions, uri.pathSegments.lastOrNull ?? l.subtitleTrack);
      await _loadTracks();
    }
  }

  Future<List<RecognizedSubtitle>> _recognizedSubtitles() async {
    final ref = _currentRef;
    if (ref == null || !_backend.supportsExternalSubtitles) return const [];
    try {
      return recognizedSubtitles((await _ensureLibrary()).db, ref);
    } catch (_) {
      return const [];
    }
  }

  static String _clock(int ms) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = ms ~/ 3600000;
    return h > 0
        ? '$h:${two(ms ~/ 60000 % 60)}:${two(ms ~/ 1000 % 60)}'
        : '${two(ms ~/ 60000)}:${two(ms ~/ 1000 % 60)}';
  }

  String _recognizedDetail(RecognizedSubtitle s) => [
    if (s.language != null && s.language!.isNotEmpty) s.language!,
    s.partial
        ? l.recognizedSubtitlePartial(
            _clock(s.rangeStartMs),
            _clock(s.rangeEndMs),
          )
        : l.recognizedSubtitleFull,
    if (s.modelId != null) s.modelId!,
  ].join(' · ');

  /// Loads a saved recognised subtitle into the current playback — on the
  /// user's choice in the panel, or when the user asked the assistant to
  /// (`playback_set_subtitle`); nothing is loaded automatically otherwise.
  Future<bool> _selectRecognized(RecognizedSubtitle s) async {
    final known = _recognizedTracks[s.bindingId];
    final ref = _currentRef;
    bool ok;
    if (known != null) {
      ok = await _adjust(() => _backend.setSubtitleTrack(known));
    } else {
      var before = <int>{};
      ok = await _adjust(() async {
        before = {for (final t in await _backend.getSubtitleTracks()) t.id};
        await _backend.addExternalSubtitle(Uri.file(s.path));
      });
      // The player registers the file asynchronously; remember its track.
      for (var i = 0; ok && i < 15 && mounted; i++) {
        final added = (await _backend.getSubtitleTracks())
            .where((t) => !before.contains(t.id))
            .firstOrNull;
        if (added != null) {
          if (_currentRef == ref) _recognizedTracks[s.bindingId] = added.id;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    if (!mounted || _currentRef != ref) return false;
    if (ok) {
      setState(() {
        _selectedRecognized = s.bindingId;
        _selectedSubtitleTrack = _recognizedTracks[s.bindingId];
      });
    }
    return ok;
  }

  /// Assistant subtitle choice: a saved recognised subtitle of the current
  /// resource (newest when [bindingId] is null), or off.
  Future<void> _assistantSubtitle(String? bindingId, bool off) async {
    // Right after opening, the native player may not accept a subtitle yet.
    for (var i = 0; i < 100 && mounted; i++) {
      final status = _backend.value.status;
      if (status == PlaybackStatus.playing || status == PlaybackStatus.paused) {
        break;
      }
      if (status == PlaybackStatus.error || status == PlaybackStatus.ended) {
        throw StateError('playbackNotActive');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (off) {
      if (!await _adjust(() => _backend.disableSubtitle())) {
        throw StateError('subtitleFailed');
      }
      if (mounted) {
        setState(() {
          _selectedSubtitleTrack = -1;
          _selectedRecognized = null;
        });
      }
      return;
    }
    final saved = await _recognizedSubtitles();
    if (saved.isEmpty) throw StateError('noSavedSubtitle');
    final choice = bindingId == null
        ? saved.first
        : saved.where((s) => s.bindingId == bindingId).firstOrNull ??
              (throw StateError('subtitleNotFound'));
    if (!await _selectRecognized(choice)) throw StateError('subtitleFailed');
  }

  // ---- Info & statistics ---------------------------------------------------

  Future<void> _loadInfo() async {
    if (!_backend.supportsMediaInfo) return;
    try {
      final info = await _backend.getMediaInfo();
      if (mounted) setState(() => _mediaInfo = info);
    } catch (error) {
      debugPrint('Media info failed: $error');
    }
    _updateStatsPolling();
  }

  void _updateStatsPolling() {
    final needed =
        _backend.supportsMediaInfo &&
        (_statsOverlay ||
            _panel == PlayerPanel.info ||
            (_panel == PlayerPanel.settings &&
                _settingsTab == SettingsTab.info));
    if (!needed) {
      _statsTimer?.cancel();
      _statsTimer = null;
      return;
    }
    if (_statsTimer != null) return;
    Future<void> sample() async {
      try {
        final stats = await _backend.getStats();
        if (mounted) setState(() => _stats = stats);
      } catch (_) {}
    }

    unawaited(sample());
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) => sample());
  }

  void _toggleStatsOverlay() {
    setState(() => _statsOverlay = !_statsOverlay);
    if (_statsOverlay) unawaited(_loadInfo());
    _updateStatsPolling();
  }

  // ---- Lifecycle ---------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _backend = widget.backend ?? LibVlcBackend();
    _sources = widget.sourceManager ?? SourceManager();
    _window = widget.fullscreen ?? WindowFullscreen();
    // Phones show the remaining time on the right by default (design M-1).
    _showRemaining = _mobileDisplay;
    if (!_mobileDisplay) {
      // Probe native support once; unsupported platforms hide the control.
      unawaited(
        _window.isFullscreen().then((value) {
          if (mounted) setState(() => _fullscreen = value);
        }),
      );
      _window.listen((value) {
        if (mounted) setState(() => _fullscreen = value);
      });
    }
    _library = widget.libraryService;
    _backend.addListener(_onPlayback);
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) _enterImmersive();
  }

  @override
  void didUpdateWidget(PlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    widget.active ? _enterImmersive() : _exitImmersive();
  }

  /// Hides the status and navigation bars on phones so the video gets the
  /// whole screen; a swipe from the edge brings them back temporarily.
  void _enterImmersive() {
    if (!_mobileDisplay) return;
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)
          .catchError((Object error) {
            debugPrint('Could not enter immersive mode: $error');
          }),
    );
  }

  void _exitImmersive() {
    if (!_mobileDisplay) return;
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)
          .catchError((Object error) {
            debugPrint('Could not restore system UI: $error');
          }),
    );
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
    final pending = _pendingSeek;
    if (pending != null &&
        // Reached the target, moved somewhere else (another seek path), or
        // the player never confirmed it.
        ((snapshot.position - pending).abs() < const Duration(seconds: 1) ||
            !_pendingSeekChain.any(
              (point) =>
                  (snapshot.position - point).abs() <
                  const Duration(milliseconds: 1500),
            ) ||
            _pendingSeekExpired)) {
      _pendingSeek = null;
    }
    // While a loop jump is in flight the stale position must not re-trigger.
    final jump = _pendingSeek == null ? _ab.jumpFor(snapshot.position) : null;
    if (jump != null && snapshot.status == PlaybackStatus.playing) {
      unawaited(_seekAbsolute(jump));
    }
    if (_lastStatus != snapshot.status) {
      final previous = _lastStatus;
      _lastStatus = snapshot.status;
      if (snapshot.status == PlaybackStatus.ended &&
          previous != PlaybackStatus.ended) {
        _onEnded();
      }
      if (mounted) setState(() => _controlsVisible = true);
      _scheduleHide();
    }
    if (_boosting && snapshot.status != PlaybackStatus.playing) {
      _endBoost();
    }
    if (_background && snapshot.status == PlaybackStatus.playing) {
      unawaited(_command(_backend.pause));
    }
  }

  void _onEnded() {
    if (_sleepAtEnd) {
      _sleepAtEnd = false;
      if (mounted) {
        setState(() {});
        showAppToast(context, l.plSleepFinished);
      }
      return;
    }
    if (_repeatOne && _name != null) unawaited(_command(_backend.play));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final away =
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
    if (away || state == AppLifecycleState.inactive) _endBoost();
    if (away) _checkpoint(force: true);
    // Phones pause in the background. Desktop windows report "hidden" when
    // minimised or covered by another window; like VLC they keep playing.
    _background = away && _mobileDisplay;
    if (_background && _name != null) unawaited(_command(_backend.pause));
    // The OS may restore the bars while the app is away.
    if (state == AppLifecycleState.resumed && widget.active) _enterImmersive();
  }

  Future<void> _command(Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stack) {
      unawaited(
        reportDiagnostic(
          DiagnosticFailure.playbackCommand,
          DiagnosticRole.player,
          stack,
        ),
      );
      debugPrint('Playback command failed: $error\n$stack');
      if (mounted) {
        setState(() {
          _controlsVisible = true;
          _error = l.playbackCommandFailed;
        });
      }
    }
  }

  /// Per-media state that must not leak into the next file.
  void _resetMediaState() {
    _drag = null;
    _pendingSeek = null;
    _selectedAudioTrack = null;
    _selectedSubtitleTrack = null;
    _ab = const AbLoop();
    _bookmarks.clear();
    _quickBookmarks.clear();
    _audioDelay = Duration.zero;
    _subtitleDelay = Duration.zero;
    _audioTracks = const [];
    _subtitleTracks = const [];
    _recognized = const [];
    _mediaInfo = null;
    _stats = null;
    _panel = PlayerPanel.none;
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
        _resetMediaState();
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
    if (_fullscreen) await _setFullscreen(false);
    if (widget.onExit != null) {
      widget.onExit!();
    } else if (await stopPlayback() && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  /// AI and UI share the same player state and backend command path.
  Map<String, dynamic> assistantSnapshot() {
    final value = _backend.value;
    return {
      'session_id': _busy || _closing ? null : _session,
      'resource_id': _resource,
      'status': value.status.name,
      'position_ms': value.position.inMilliseconds,
      'duration_ms': value.duration.inMilliseconds,
      'can_seek': value.canSeek,
      'speed': value.speed,
      'volume': value.volume,
      'subtitle': _selectedRecognized != null
          ? {'kind': 'recognized', 'binding_id': _selectedRecognized}
          : _selectedSubtitleTrack == null || _selectedSubtitleTrack! < 0
          ? {'kind': 'off_or_default'}
          : {'kind': 'embedded'},
    };
  }

  Future<Map<String, dynamic>> assistantControl(
    String command,
    Map<String, dynamic> args,
  ) async {
    if (_busy ||
        _closing ||
        _session == null ||
        args['session_id'] != _session) {
      throw StateError('staleSession');
    }
    final session = _session;
    switch (command) {
      case 'pause':
        await _backend.pause();
      case 'resume':
        await _backend.play();
      case 'stop':
        if (!await stopPlayback()) throw StateError('stopFailed');
      case 'seek':
        final position = args['position_ms'] as int;
        if (!_backend.value.canSeek ||
            position > _backend.value.duration.inMilliseconds) {
          throw StateError('invalidPosition');
        }
        await _backend.seek(Duration(milliseconds: position));
      case 'set_speed':
        final speed = (args['speed'] as num).toDouble();
        if (!const [
          0.25,
          0.5,
          0.75,
          1.0,
          1.25,
          1.5,
          1.75,
          2.0,
          3.0,
          4.0,
        ].contains(speed)) {
          throw StateError('unsupportedSpeed');
        }
        await _backend.setSpeed(speed);
        if (mounted) setState(() => _speed = speed);
      case 'set_volume':
        await _backend.setVolume(args['volume'] as int);
      case 'set_subtitle':
        await _assistantSubtitle(
          args['binding_id'] as String?,
          args['off'] == true,
        );
      default:
        throw StateError('unsupportedCommand');
    }
    if (command != 'stop' && session != _session) {
      throw StateError('staleSession');
    }
    _checkpoint(force: true);
    return assistantSnapshot();
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
      _sleepTimer?.cancel();
      setState(() {
        _name = null;
        _displayTitle = null;
        _error = null;
        _locked = false;
        _videoQuarterTurns = 0;
        _frame = const VideoFrameSettings();
        _screenOrientation = PlayerScreenOrientation.system;
        _controlsVisible = true;
        _sleepAt = null;
        _sleepAtEnd = false;
        _statsOverlay = false;
        _resetMediaState();
      });
      _ensureClock();
      _updateStatsPolling();
      return true;
    } catch (_) {
      if (mounted) {
        showAppToast(context, l.stopPlaybackFailed, kind: FeedbackKind.error);
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
        _displayTitle = null;
        _error = null;
        _resetMediaState();
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
    if (widget.active) _exitImmersive();
    unawaited(
      _orientationSession.restore().catchError((Object error) {
        debugPrint('Could not restore screen orientation: $error');
      }),
    );
    if (!_mobileDisplay) _window.stopListening();
    _playerFocus.dispose();
    controlsVisibility.dispose();
    _finishTracking();
    if (widget.libraryService == null) _library?.close();
    _hideTimer?.cancel();
    _osdTimer?.cancel();
    _sleepTimer?.cancel();
    _clockTimer?.cancel();
    _statsTimer?.cancel();
    _tapSeekTimer?.cancel();
    _feedbackTimer?.cancel();
    _unlockTimer?.cancel();
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

  /// setState for the layout extensions in the part files.
  void _update(VoidCallback fn) => setState(fn);

  // ---- Controls visibility (design §3.6) ---------------------------------

  Duration get _hideDelay =>
      _mobileDisplay ? _prefs.mobileHideDelay : _prefs.desktopHideDelay;

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
        _panel != PlayerPanel.none ||
        _error != null ||
        _backend.value.status != PlaybackStatus.playing) {
      return;
    }
    _hideTimer = Timer(_hideDelay, () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    if (_locked) return;
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    if (_controlsVisible && _name != null && _error == null) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  void _panelOpened() {
    _openPanels++;
    _hideTimer?.cancel();
  }

  void _panelClosed() {
    if (_openPanels > 0) _openPanels--;
    _scheduleHide();
  }

  void _openPanel(PlayerPanel panel) {
    if (_locked) return;
    _endBoost();
    _hideTimer?.cancel();
    setState(() {
      _panel = _panel == panel ? PlayerPanel.none : panel;
      _controlsVisible = true;
    });
    if (_panel == PlayerPanel.tracks || _panel == PlayerPanel.sync) {
      unawaited(_loadTracks());
    }
    if (_panel == PlayerPanel.info ||
        (_panel == PlayerPanel.settings && _settingsTab == SettingsTab.info)) {
      unawaited(_loadInfo());
    }
    _updateStatsPolling();
    _scheduleHide();
  }

  void _closePanel() {
    if (_panel == PlayerPanel.none) return;
    setState(() => _panel = PlayerPanel.none);
    _updateStatsPolling();
    _scheduleHide();
    _playerFocus.requestFocus();
  }

  void _lock() {
    _endBoost();
    _hideTimer?.cancel();
    setState(() {
      _drag = null;
      _locked = true;
      _hoveringControls = false;
      _panel = PlayerPanel.none;
      _showUnlock = true;
    });
    _armUnlockHint();
  }

  void _unlock() {
    _unlockTimer?.cancel();
    setState(() {
      _locked = false;
      _showUnlock = false;
      _controlsVisible = true;
    });
    _scheduleHide();
  }

  /// Fading control layer. [opaque] false lets touches outside the
  /// controls fall through to the video (full-screen layers); touches on
  /// the controls still stop here (MouseRegion.opaque false would let them
  /// reach the video's recognizers too).
  Widget _chrome(Widget child, {bool opaque = true}) => MouseRegion(
    hitTestBehavior: opaque ? null : HitTestBehavior.deferToChild,
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
          duration: AppMotion.duration(context, AppMotion.controls),
          child: child,
        ),
      ),
    ),
  );

  /// macOS draws the native window buttons over the top-left of the player.
  /// They disappear in native full screen, where no space needs reserving.
  bool _reservesWindowButtons(BuildContext context) {
    if (kIsWeb || !Platform.isMacOS || _fullscreen) return false;
    final view = View.of(context);
    final size = MediaQuery.sizeOf(context) * view.devicePixelRatio;
    return size.height < view.display.size.height - 1;
  }

  /// System insets (status bar, camera cutout, home indicator) the controls
  /// keep clear of. Read from the page context, above the player's own
  /// padding removal, so the video itself can run edge to edge.
  EdgeInsets get _insets => MediaQuery.paddingOf(context);

  String get _title => _displayTitle ?? _name ?? 'OpenPlayX';

  /// Second header line (design D-1): the file name when the library
  /// supplied a different display title.
  String? get _subtitle {
    String strip(String text) =>
        text.replaceFirst(RegExp(r'\.[A-Za-z0-9]{2,4}$'), '').trim();
    final name = _name == null ? null : strip(_name!);
    final title = _displayTitle == null ? null : strip(_displayTitle!);
    return title != null && name != null && name.isNotEmpty && name != title
        ? name
        : null;
  }

  /// Current position text, honouring the remaining-time preference.
  /// Player input read speed shown beside the time (docs: 读取速度).
  Widget _readSpeedLabel(PlayerSnapshot value) => Text(
    l.readSpeed(
      value.readSpeedMBps == null
          ? '--'
          : value.readSpeedMBps!.toStringAsFixed(2),
    ),
    key: const Key('playback-read-speed'),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      color: PlayerStyle.muted,
      fontSize: 12,
      fontFeatures: PlayerStyle.tabular,
      shadows: PlayerStyle.shadow,
    ),
  );

  String _timeText(PlayerSnapshot value, double position) {
    final duration = value.duration;
    final current = formatClock(
      Duration(milliseconds: position.round()),
      duration,
    );
    if (duration <= Duration.zero) return '$current / --:--';
    if (_showRemaining) {
      final rest = duration - Duration(milliseconds: position.round());
      return '$current / -${formatClock(rest.isNegative ? Duration.zero : rest, duration)}';
    }
    return '$current / ${formatClock(duration, duration)}';
  }

  SeekMarks _marks(PlayerSnapshot value) {
    final total = value.duration.inMilliseconds;
    if (total <= 0) return const SeekMarks();
    double f(Duration d) => (d.inMilliseconds / total).clamp(0, 1);
    return SeekMarks(
      a: _ab.a == null ? null : f(_ab.a!),
      b: _ab.b == null ? null : f(_ab.b!),
      bookmarks: [for (final b in _bookmarks) f(b.position)],
    );
  }

  /// Position shown by the bar and time labels: drag preview, then a
  /// pending seek target, then the player's position.
  double _shownPosition(PlayerSnapshot value) {
    final duration = value.duration.inMilliseconds.toDouble();
    return (_drag ?? _position.inMilliseconds.toDouble()).clamp(
      0.0,
      duration > 0 ? duration : 1.0,
    );
  }

  Widget _seekBar(PlayerSnapshot value, {double lane = 20}) {
    final duration = value.duration.inMilliseconds.toDouble();
    final position = (_drag ?? _position.inMilliseconds.toDouble()).clamp(
      0.0,
      duration > 0 ? duration : 1.0,
    );
    return PlayerSeekBar(
      key: const Key('playback-progress'),
      value: position,
      max: duration > 0 ? duration : 1,
      enabled: _seekable,
      label: l.playbackPosition,
      lane: lane,
      alwaysShowThumb: _mobileDisplay,
      marks: _marks(value),
      hoverLabel: _mobileDisplay
          ? null
          : (ms) =>
                formatClock(Duration(milliseconds: ms.round()), value.duration),
      onPreview: (value) {
        _hideTimer?.cancel();
        setState(() => _drag = value);
      },
      onCommit: (value) async {
        final seek = _seekAbsolute(Duration(milliseconds: value.round()));
        setState(() => _drag = null);
        await seek;
        _scheduleHide();
      },
    );
  }

  /// Status pills for settings away from their defaults (design L3).
  List<Widget> _statusChips() {
    final chips = <Widget>[];
    if (_speed != 1) {
      chips.add(
        PlayerChip(
          icon: AppIcons.speed,
          label: formatSpeed(_speed),
          tooltip: l.playbackSpeed,
          onTap: () => _openPanel(PlayerPanel.speed),
          onReset: () => _setSpeed(1),
        ),
      );
    }
    if (_sleepAt != null || _sleepAtEnd) {
      final left = _sleepAt?.difference(DateTime.now());
      chips.add(
        PlayerChip(
          icon: AppIcons.sleep,
          label: left == null
              ? l.plSleepEndOfItem
              : formatTime(left.isNegative ? Duration.zero : left),
          tooltip: l.plSleepTimer,
          onTap: () => _openPanel(PlayerPanel.sleep),
          onReset: () => _setSleep(null),
        ),
      );
    }
    if (_ab.phase != AbPhase.off) {
      chips.add(
        PlayerChip(
          icon: AppIcons.repeatOne,
          label: _ab.phase == AbPhase.aSet ? 'A-' : 'A-B',
          tooltip: l.plAbLoop,
          onTap: _advanceAb,
          onReset: () => setState(() => _ab = const AbLoop()),
        ),
      );
    }
    if (_audioDelay != Duration.zero) {
      chips.add(
        PlayerChip(
          icon: AppIcons.audio,
          label: formatDelay(_audioDelay),
          tooltip: l.plAudioDelay,
          onTap: () => _openSync(),
          onReset: () => _setAudioDelay(Duration.zero),
        ),
      );
    }
    if (_subtitleDelay != Duration.zero) {
      chips.add(
        PlayerChip(
          icon: AppIcons.captions,
          label: formatDelay(_subtitleDelay),
          tooltip: l.plSubtitleDelay,
          onTap: () => _openSync(),
          onReset: () => _setSubtitleDelay(Duration.zero),
        ),
      );
    }
    if (!_frame.isDefault) {
      chips.add(
        PlayerChip(
          icon: AppIcons.aspect,
          label:
              videoAspectLabels[_frame.aspectIndex] ?? _fitLabel(_frame.mode),
          tooltip: l.plPicture,
          onTap: () => _openFrame(),
          onReset: () => setState(() => _frame = const VideoFrameSettings()),
        ),
      );
    }
    if (_repeatOne) {
      chips.add(
        PlayerChip(
          icon: AppIcons.repeatOne,
          label: l.plRepeatOne,
          onTap: () => _perform(PlayerAction.cycleRepeat),
          onReset: () => setState(() => _repeatOne = false),
        ),
      );
    }
    return chips;
  }

  void _openSync() {
    if (_mobileDisplay) {
      _openPanel(PlayerPanel.sync);
    } else {
      _settingsTab = SettingsTab.sync;
      if (_panel != PlayerPanel.settings) _openPanel(PlayerPanel.settings);
    }
  }

  void _openFrame() {
    if (_mobileDisplay) {
      _openPanel(PlayerPanel.frame);
    } else {
      _settingsTab = SettingsTab.picture;
      if (_panel != PlayerPanel.settings) _openPanel(PlayerPanel.settings);
    }
  }

  Future<void> _askJumpToTime() async {
    if (!_seekable) return;
    final controller = TextEditingController(
      text: formatTime(_backend.value.position),
    );
    _panelOpened();
    String? error;
    try {
      final target = await showShadDialog<Duration>(
        context: context,
        builder: (context) => ShadTheme(
          data: AppTheme.dark,
          child: StatefulBuilder(
            builder: (context, update) {
              void submit() {
                final parsed = parseClock(controller.text);
                if (parsed == null) {
                  update(() => error = l.plJumpToTimeInvalid);
                } else {
                  Navigator.pop(context, parsed);
                }
              }

              return ShadDialog(
                title: Text(l.plJumpToTime),
                actions: [
                  ShadButton.outline(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.cancel),
                  ),
                  ShadButton(onPressed: submit, child: Text(l.plGo)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShadInput(
                        key: const Key('jump-to-time-input'),
                        controller: controller,
                        autofocus: true,
                        placeholder: const Text('1:23:45'),
                        onSubmitted: (_) => submit(),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          error!,
                          style: TextStyle(
                            color: ShadTheme.of(context)
                                .colorScheme
                                .destructive,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      if (target != null && mounted) _seekTo(target);
    } finally {
      controller.dispose();
      _panelClosed();
    }
  }

  // ---- Build -----------------------------------------------------------

  /// Portrait phones put the picture at the top, under the top bar, with
  /// the controls below it (design M-7).
  bool get _portraitPhone {
    if (!_mobileDisplay) return false;
    final size = MediaQuery.sizeOf(context);
    return size.height > size.width;
  }

  double get _portraitTop => _insets.top + 56;

  /// Picture rectangle in portrait: full width at the video's ratio
  /// (16:9 until the size is known), below the top bar.
  Rect _portraitVideoRect(Size screen) {
    final video = _backend.value.videoSize;
    final ratio = video == null || video.isEmpty
        ? 16 / 9
        : video.width / video.height;
    final room = screen.height - _portraitTop;
    final height = (screen.width / ratio).clamp(0.0, room * 0.6);
    return Rect.fromLTWH(0, _portraitTop, screen.width, height);
  }

  Widget _video() => LayoutBuilder(
    builder: (context, box) {
      final screen = Size(box.maxWidth, box.maxHeight);
      final portrait = _portraitPhone;
      final top = portrait ? _portraitTop : 0.0;
      final frame = portrait
          ? _portraitVideoRect(screen)
          : Offset.zero & screen;
      final rotated = _videoQuarterTurns.isOdd;
      final area = rotated
          ? Size(frame.height, frame.width)
          : Size(frame.width, frame.height);
      final layout = layoutVideo(area, _backend.value.videoSize, _frame);
      // The same widget structure for every layout and orientation: changing
      // the tree around the native view would recreate it and reload the
      // media. Only sizes, padding and alignment values change.
      final view = OverflowBox(
        alignment: portrait ? Alignment.topCenter : Alignment.center,
        minWidth: 0,
        minHeight: 0,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Transform.scale(
          scaleX: layout.scaleX,
          scaleY: layout.scaleY,
          child: SizedBox.fromSize(
            size: layout.size,
            child: PlayerVideoView(backend: _backend),
          ),
        ),
      );
      return ClipRect(
        child: Padding(
          padding: EdgeInsets.only(top: top),
          child: SizedBox(
            height: portrait ? frame.height : null,
            child: ClipRect(
              child: RotatedBox(
                key: const Key('video-rotation'),
                quarterTurns: _videoQuarterTurns,
                child: view,
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _videoLayer() => Stack(
    fit: StackFit.expand,
    children: [
      IgnorePointer(
        child: ValueListenableBuilder<PlayerSnapshot>(
          valueListenable: _backend,
          builder: (context, _, _) => _video(),
        ),
      ),
      IgnorePointer(
        child: ColoredBox(
          key: const Key('video-dimming'),
          color: AppSemanticColors.playerSurface.withValues(
            alpha: (1 - _brightness) * 0.85,
          ),
        ),
      ),
    ],
  );

  List<Widget> _statusLayers() => [
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
                const SizedBox(height: 12),
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
    // VLCKit keeps reporting buffering during normal playback, so only the
    // opening phase shows the loading indicator.
    if (_busy || _backend.value.status == PlaybackStatus.opening)
      IgnorePointer(
        child: Center(
          child: SizedBox(
            width: 120,
            child: ShadProgress(semanticsLabel: l.loading),
          ),
        ),
      ),
    if (_error != null || _backend.value.status == PlaybackStatus.error)
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error ?? l.playbackFailed,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    if (_boosting)
      Positioned(
        top: 64 + _insets.top,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: _mobileDisplay
                ? PlayerOsd(
                    icon: AppIcons.forwardOsd,
                    text: l.plBoostingShort(formatSpeed(boostSpeed(_speed))),
                    detail: l.plSwipeUpToLock,
                  )
                : PlayerOsd(
                    icon: AppIcons.forwardOsd,
                    text: l.plBoosting(formatSpeed(boostSpeed(_speed))),
                  ),
          ),
        ),
      ),
    if (_osd != null && !_boosting)
      Positioned.fill(
        child: Align(
          alignment: const Alignment(0, -0.15),
          child: PlayerOsd(
            key: const Key('player-osd'),
            icon: _osd!.icon,
            text: _osd!.text,
            detail: _osd!.detail,
          ),
        ),
      ),
    if (_statsOverlay)
      Positioned(
        top: 56 + _insets.top,
        left: 16 + _insets.left,
        child: ValueListenableBuilder<PlayerSnapshot>(
          valueListenable: _backend,
          builder: (context, _, _) => _statsCard(),
        ),
      ),
  ];

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    // The player is always dark, so bars revealed by an edge swipe need
    // light icons whatever the app theme is.
    value: appSystemUiStyle(Brightness.dark),
    child: ShadTheme(
      data: AppTheme.dark,
      child: Focus(
        focusNode: _playerFocus,
        autofocus: true,
        onKeyEvent: _handlePlayerKey,
        child: Scaffold(
          backgroundColor: AppSemanticColors.playerSurface,
          // The video fills the whole screen, camera cutout included; the
          // controls add the system insets themselves (see [_insets]).
          body: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            removeBottom: true,
            removeLeft: true,
            removeRight: true,
            child: _mobileDisplay ? _mobileBody() : _desktopBody(),
          ),
        ),
      ),
    ),
  );
}

/// Time label sized by the media length: "00:41:22" for media of an hour
/// or more (VLC style), "41:22" otherwise.
String formatClock(Duration time, Duration reference) {
  if (reference < const Duration(hours: 1)) return formatTime(time);
  final seconds = time.inSeconds.clamp(0, 999999999);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(seconds ~/ 3600)}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}';
}

String formatTime(Duration time) {
  final seconds = time.inSeconds.clamp(0, 999999999);
  final minutes = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return seconds >= 3600
      ? '${seconds ~/ 3600}:$minutes:$rest'
      : '$minutes:$rest';
}

/// Parses "ss", "mm:ss" or "h:mm:ss" into a duration.
Duration? parseClock(String text) {
  final parts = text.trim().split(':');
  if (parts.isEmpty || parts.length > 3) return null;
  final numbers = [for (final p in parts) int.tryParse(p.trim())];
  if (numbers.any((n) => n == null || n < 0)) return null;
  var seconds = 0;
  for (final n in numbers) {
    seconds = seconds * 60 + n!;
  }
  return Duration(seconds: seconds);
}

/// Convenience used by the mobile gesture layer.
double _clamp01(double value) => math.min(1, math.max(0, value));
