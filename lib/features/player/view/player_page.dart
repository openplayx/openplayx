import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import '../../settings/app_theme_controller.dart';
import '../adapters/player_assistant.dart';
import '../controller/audio_track_controller.dart';
import '../controller/media_info_controller.dart';
import '../controller/playback_history.dart';
import '../controller/playback_tools_controller.dart';
import '../controller/player_controller.dart';
import '../controller/player_orientation_session.dart';
import '../controller/subtitle_controller.dart';
import '../model/audio_track_state.dart';
import '../model/subtitle_state.dart';
import '../model/playback_tools_state.dart';
import '../model/player_action.dart';
import '../model/player_orientation.dart';
import '../model/player_prefs.dart';
import '../model/player_state.dart';
import '../model/player_ui_state.dart';
import '../model/video_frame.dart';
import 'player_keymap.dart';
import 'widgets/player_widgets.dart';
import 'window_fullscreen.dart';
import '../../../l10n/generated/app_localizations.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/theme/app_theme.dart';
import '../../../ui/theme/system_ui.dart';
import '../../../ui/tokens/app_semantic_colors.dart';
import '../../../ui/tokens/app_motion.dart';
import '../../../ui/icons/app_icons.dart';

import 'package:flutter/services.dart';
import 'package:openplayx_playback/playback.dart';

import '../../../data/files/local_media_picker.dart';
import '../../../capabilities/sources/source_manager.dart';
import '../../../capabilities/library/library_service.dart';
import '../../../capabilities/speech/recognized_subtitles.dart';
import '../../../ui/components/feedback/app_feedback.dart';

part 'player_actions.dart';
part 'player_desktop.dart';
part 'player_mobile.dart';
part 'player_panels.dart';

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
  late final PlayerController _player;
  late final Listenable _playerListeners;
  late final PlayerAssistant _assistant;
  PlayerState get _playerState => _player.state;
  PlaybackHistory get _history => _player.history;
  PlaybackToolsController get _tools => _player.tools;
  AudioTrackController get _audio => _player.audio;
  SubtitleController get _subtitles => _player.subtitles;
  MediaInfoController get _info => _player.info;
  String? get _name => _playerState.name;
  PlayerError? get _error => _playerState.error;
  bool get _busy => _playerState.busy;
  bool get _closing => _playerState.closing;
  PlayerMediaInfo? get _mediaInfo => _info.state.info;
  PlayerStats? get _stats => _info.state.stats;

  // Scraped/edited library title, preferred over the file name in the header.
  String? _displayTitle;
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
  bool _locked = false;
  double _brightness = 1;
  PlaybackToolsState get _toolsState => _tools.state;
  double get _speed => _toolsState.speed;
  bool get _boosting => _toolsState.boosting;
  AbLoop get _ab => _toolsState.ab;
  DateTime? get _sleepAt => _toolsState.sleepAt;
  bool get _sleepAtEnd => _toolsState.sleepAtEnd;
  bool get _repeatOne => _toolsState.repeatOne;
  Duration get _position => _tools.position;
  AudioTrackState get _audioState => _audio.state;
  SubtitleState get _subtitleState => _subtitles.state;

  final _playerFocus = FocusNode(debugLabel: 'player-keyboard');

  // ---- Design v0.2 state -------------------------------------------------
  PlayerPanel _panel = PlayerPanel.none;
  SettingsTab _settingsTab = SettingsTab.picture;
  bool _showRemaining = false;
  final _tracksButtonKey = GlobalKey();
  final _speedButtonKey = GlobalKey();
  bool _fullscreen = false;
  bool _statsOverlay = false;
  bool _advancedTools = false;
  VideoFrameSettings _frame = const VideoFrameSettings();
  Timer? _clockTimer;
  ({IconData? icon, String text, String? detail})? _osd;
  Timer? _osdTimer;
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

  void _togglePlayback() {
    if (!_enabled) return;
    _endBoost();
    _tools.playToggled();
    unawaited(
      _command(
        _backend.value.status == PlaybackStatus.playing
            ? _backend.pause
            : _backend.play,
      ),
    );
  }

  final _orientationSession = PlayerOrientationSession();
  StreamSubscription<dynamic>? _deviceOrientationSubscription;
  bool _followSystemOrientation = true;
  PlayerScreenOrientation get _currentOrientation =>
      MediaQuery.orientationOf(context) == Orientation.landscape
      ? PlayerScreenOrientation.landscape
      : PlayerScreenOrientation.portrait;
  PlayerScreenOrientation get _targetOrientation =>
      _currentOrientation == PlayerScreenOrientation.portrait
      ? PlayerScreenOrientation.landscape
      : PlayerScreenOrientation.portrait;
  String get _rotateLabel =>
      _targetOrientation == PlayerScreenOrientation.landscape
      ? l.plSwitchToLandscape
      : l.plSwitchToPortrait;

  Future<void> _toggleOrientation() async {
    if (!_enabled || _changingDisplay) return;
    final target = _targetOrientation;
    setState(() => _changingDisplay = true);
    try {
      await _adjust(() => _orientationSession.apply(target));
    } finally {
      if (mounted) setState(() => _changingDisplay = false);
    }
  }

  int _videoQuarterTurns = 0;
  bool _changingDisplay = false;

  bool get _enabled => _player.canControlMedia && !_locked;

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

  Future<void> _setSpeed(double speed) async {
    final applied = await _tools.setSpeed(speed);
    if (applied != null && mounted) {
      _flash(AppIcons.speed, formatSpeed(applied));
    }
  }

  void _startBoost() {
    if (!_tools.startBoost()) return;
    _hideTimer?.cancel();
    HapticFeedback.selectionClick();
  }

  /// Swipe up during a long press keeps the boost speed (design MG10).
  void _lockBoost() {
    final speed = _tools.lockBoost();
    if (speed == null) return;
    HapticFeedback.mediumImpact();
    _flash(AppIcons.speed, l.plSpeedLocked(formatSpeed(speed)));
    _scheduleHide();
  }

  void _endBoost() {
    if (_tools.endBoost()) _scheduleHide();
  }

  void _skip(int seconds) => _jump(Duration(seconds: seconds));

  Future<void> _seekAbsolute(Duration target) => _tools.seekAbsolute(target);

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
    final applied = await _tools.setVolume(volume);
    if (applied != null) {
      _flash(applied == 0 ? AppIcons.muted : AppIcons.volume, '$applied%');
    }
  }

  Future<void> _toggleMute() async {
    final next = await _tools.toggleMute();
    if (next != null) {
      _flash(
        next == 0 ? AppIcons.muted : AppIcons.volume,
        next == 0 ? l.plMuted : '$next%',
      );
    }
  }

  Future<void> _setAudioDelay(Duration delay) async {
    if (await _audio.setDelay(delay) && mounted) {
      _flash(AppIcons.audio, '${l.plAudioDelay} ${formatDelay(delay)}');
    }
  }

  Future<void> _setSubtitleDelay(Duration delay) async {
    if (await _subtitles.setDelay(delay) && mounted) {
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
    if (await _tools.stopToStart(seekable: _seekable)) {
      _flash(AppIcons.stop, l.plStop);
    }
  }

  Future<void> _setFullscreen(bool value) async {
    if (_mobileDisplay || !_window.isSupported) return;
    final result = await _window.setFullscreen(value);
    if (mounted) setState(() => _fullscreen = result);
  }

  void _advanceAb() {
    if (!_seekable) return;
    final ab = _tools.advanceAb();
    _flash(AppIcons.repeatOne, switch (ab.phase) {
      AbPhase.off => l.plAbCleared,
      AbPhase.aSet => l.plAbASet(formatTime(ab.a!)),
      AbPhase.looping => l.plAbLooping(formatTime(ab.a!), formatTime(ab.b!)),
    });
  }

  void _setSleep(int? minutes) {
    _tools.setSleep(minutes);
    _ensureClock();
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
      final file = await _tools.saveSnapshot(
        title: _displayTitle ?? _name ?? 'OpenPlayX',
        mobile: _mobileDisplay,
      );
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
    try {
      await _audio.refresh();
      await _subtitles.refresh();
    } catch (error) {
      debugPrint('Track listing failed: $error');
    }
  }

  String _audioName(PlayerAudioTrack track) =>
      track.name.isEmpty ? l.numberedAudioTrack(track.id) : track.name;

  /// Display name of a subtitle option in lists, menus and the OSD.
  String _subtitleName(SubtitleOption option) => switch (option.source) {
    EmbeddedSubtitle() =>
      option.name.isEmpty
          ? l.numberedSubtitleTrack(option.playerId ?? 0)
          : option.name,
    ExternalSubtitle() => option.name,
    RecognizedSubtitleSource(:final saved) =>
      '${l.recognizedSubtitleBadge} · ${l.recognizedSubtitleTitle(saved.created.toLocal().toString().substring(0, 16))}',
  };

  /// Second line of a subtitle option: loading, language or recognition
  /// details.
  String? _subtitleDetail(SubtitleOption option) => option.loading
      ? l.loading
      : switch (option.source) {
          EmbeddedSubtitle() => option.language,
          ExternalSubtitle() => null,
          RecognizedSubtitleSource(:final saved) => _recognizedDetail(saved),
        };

  Future<void> _selectAudio(int id) async {
    if (!_enabled) return;
    if (await _audio.select(id) && mounted) {
      final track = _audioState.tracks.where((t) => t.id == id).firstOrNull;
      _flash(AppIcons.audio, track == null ? l.audioTrack : _audioName(track));
    }
  }

  /// Applies a subtitle choice from the UI (off or an option): a saved
  /// recognised subtitle is loaded only when the user picks it.
  Future<void> _applySubtitle(SubtitleSelection target) async {
    if (!_enabled) return;
    if (!await _subtitles.apply(target) || !mounted) return;
    final option = target is SubtitleChosen
        ? _subtitleState.option(target.key)
        : null;
    _flash(
      AppIcons.captions,
      target is SubtitleOff
          ? l.subtitleOff
          : option == null
          ? l.subtitleTrack
          : _subtitleName(option),
    );
  }

  Future<void> _chooseSubtitle(SubtitleOption option) =>
      _applySubtitle(SubtitleChosen(option.key));

  Future<void> _subtitleOff() => _applySubtitle(const SubtitleOff());

  Future<void> _cycleAudioTrack() async {
    await _loadTracks();
    final next = _audioState.nextTrack;
    if (next == null) {
      _flash(AppIcons.audio, l.noAudioTracks);
      return;
    }
    await _selectAudio(next);
  }

  Future<void> _cycleSubtitle(int direction) async {
    await _loadTracks();
    final target = _subtitleState.cycleTarget(direction);
    if (target == null) {
      _flash(AppIcons.captions, l.noSubtitleTracks);
      return;
    }
    await _applySubtitle(target);
  }

  Future<void> _toggleSubtitles() async {
    if (_subtitleState.isOff) await _loadTracks();
    final target = _subtitleState.toggleTarget;
    if (target != null) await _applySubtitle(target);
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
    if (await _subtitles.addFile(uri)) {
      _flash(AppIcons.captions, uri.pathSegments.lastOrNull ?? l.subtitleTrack);
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

  // ---- Info & statistics ---------------------------------------------------

  Future<void> _loadInfo() async {
    if (!_backend.supportsMediaInfo) return;
    await _info.load();
    _updateStatsPolling();
  }

  void _updateStatsPolling() => _info.updatePolling(
    _statsOverlay ||
        _panel == PlayerPanel.info ||
        (_panel == PlayerPanel.settings && _settingsTab == SettingsTab.info),
  );

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
    _player = PlayerController(
      backend: _backend,
      sources: _sources,
      library: widget.libraryService,
      attempt: _adjust,
      canControl: () => _enabled,
      onSaveFailed: () {
        if (mounted) {
          showAppToast(context, l.historySaveFailed, kind: FeedbackKind.error);
        }
      },
      onTitle: (title) {
        if (mounted) setState(() => _displayTitle = title);
      },
      onSleepFinished: () {
        if (mounted) showAppToast(context, l.plSleepFinished);
      },
      onCommandFailed: () {
        if (mounted) setState(() => _controlsVisible = true);
      },
      onStatusChanged: () {
        if (_mobileDisplay) {
          if (_backend.value.status == PlaybackStatus.ended) {
            unawaited(_adjust(_orientationSession.restore));
          } else if (_backend.value.status == PlaybackStatus.playing &&
              !_orientationSession.active) {
            unawaited(
              _adjust(
                () => _orientationSession.start(
                  followSystem: _followSystemOrientation,
                  current: _currentOrientation,
                ),
              ),
            );
          }
        }
        if (mounted) setState(() => _controlsVisible = true);
        _scheduleHide();
      },
      onBoostEnded: _scheduleHide,
    );
    _assistant = PlayerAssistant(player: _player, stop: stopPlayback);
    _playerListeners = Listenable.merge([
      _player,
      _tools,
      _audio,
      _subtitles,
      _info,
    ])..addListener(_rebuild);
    if (_mobileDisplay) {
      _deviceOrientationSubscription =
          const EventChannel('openplayx/device_orientation')
              .receiveBroadcastStream()
              .listen(
                (event) {
                  if (event is String) {
                    unawaited(
                      _adjust(
                        () =>
                            _orientationSession.deviceOrientationChanged(event),
                      ),
                    );
                  }
                },
                onError: (Object error) {
                  debugPrint('Device orientation unavailable: $error');
                },
              );
    }
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) _enterImmersive();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _followSystemOrientation =
        AppAppearance.maybeOf(context)?.followSystemOrientation ?? true;
    if (_mobileDisplay) {
      unawaited(
        _adjust(
          () => _orientationSession.setFollowSystem(
            _followSystemOrientation,
            _currentOrientation,
          ),
        ),
      );
    }
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final away =
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
    if (away || state == AppLifecycleState.inactive) _endBoost();
    if (away) _history.checkpoint(force: true);
    // Phones pause in the background. Desktop windows report "hidden" when
    // minimised or covered by another window; like VLC they keep playing.
    _player.setBackground(away && _mobileDisplay);
    // The OS may restore the bars while the app is away.
    if (state == AppLifecycleState.resumed && widget.active) _enterImmersive();
  }

  Future<void> _command(Future<void> Function() action) =>
      _player.command(action);

  /// Per-media state that must not leak into the next file.
  void _resetMediaState() {
    _drag = null;
    _panel = PlayerPanel.none;
    if (_mobileDisplay && _name != null) {
      unawaited(
        _adjust(
          () => _orientationSession.start(
            followSystem: _followSystemOrientation,
            current: _currentOrientation,
          ),
        ),
      );
    }
  }

  Future<void> _open() async {
    _endBoost();
    await _tools.speedCommands;
    if (!mounted) return;
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    _player.setBusy(true);
    try {
      final media = await widget.pickMedia();
      if (media == null || !mounted) return;
      widget.onFileSelected?.call();
      _player.beginMedia(media.name);
      setState(_resetMediaState);
      await _player.openLocal(media);
    } catch (error, stack) {
      debugPrint('File selection failed: $error\n$stack');
      if (mounted) _player.failOpen();
    } finally {
      if (mounted) {
        _player.setBusy(false);
        _scheduleHide();
      }
    }
  }

  Future<void>? _openingMedia;

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
  Map<String, dynamic> assistantSnapshot() => _assistant.snapshot();

  Future<Map<String, dynamic>> assistantControl(
    String command,
    Map<String, dynamic> args,
  ) => _assistant.control(command, args);

  Future<bool> stopPlayback() async {
    if (_closing) return false;
    _player.setClosing(true);
    _endBoost();
    try {
      await _openingMedia;
      await _tools.speedCommands;
      if (!mounted) return false;
      await _player.stopMedia(
        restoreDisplay: () async {
          // Native orientation replies can be delayed, including by an earlier
          // queued change. Restore in order without blocking cleanup or exit.
          unawaited(_adjust(_orientationSession.restore));
        },
      );
      if (!mounted) return false;
      _hideTimer?.cancel();
      _player.endMedia();
      setState(() {
        _displayTitle = null;
        _locked = false;
        _videoQuarterTurns = 0;
        _frame = const VideoFrameSettings();
        _controlsVisible = true;
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
      _player.setClosing(false);
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
    await _tools.speedCommands;
    if (!mounted) {
      await selection.stream.release();
      return;
    }
    _player.setBusy(true);
    try {
      _player.beginMedia(selection.name);
      setState(() {
        _displayTitle = null;
        _resetMediaState();
      });
      await _player.openSelection(selection);
    } finally {
      if (mounted) {
        _player.setBusy(false);
        _scheduleHide();
      }
    }
  }

  @override
  void dispose() {
    unawaited(_deviceOrientationSubscription?.cancel());
    if (widget.active) _exitImmersive();
    unawaited(
      _orientationSession.restore().catchError((Object error) {
        debugPrint('Could not restore screen orientation: $error');
      }),
    );
    if (!_mobileDisplay) _window.stopListening();
    _playerFocus.dispose();
    controlsVisibility.dispose();
    _playerListeners.removeListener(_rebuild);
    _player.dispose();
    _hideTimer?.cancel();
    _osdTimer?.cancel();
    _clockTimer?.cancel();
    _tapSeekTimer?.cancel();
    _feedbackTimer?.cancel();
    _unlockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _backend.dispose();
    unawaited(_releaseSources());
    super.dispose();
  }

  Future<void> _releaseSources() async {
    await _player.releaseStream();
    if (widget.sourceManager == null) await _sources.dispose();
  }

  /// setState for the layout extensions in the part files.
  void _update(VoidCallback fn) => setState(fn);

  /// Rebuilds after a controller changed its state.
  void _rebuild() {
    if (mounted) setState(() {});
  }

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
    if (const {
      PlayerPanel.tracks,
      PlayerPanel.audio,
      PlayerPanel.subtitles,
      PlayerPanel.sync,
    }.contains(_panel)) {
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
          onReset: _tools.clearAb,
        ),
      );
    }
    if (_audioState.delay != Duration.zero) {
      chips.add(
        PlayerChip(
          icon: AppIcons.audio,
          label: formatDelay(_audioState.delay),
          tooltip: l.plAudioDelay,
          onTap: () => _openSync(),
          onReset: () => _setAudioDelay(Duration.zero),
        ),
      );
    }
    if (_subtitleState.delay != Duration.zero) {
      chips.add(
        PlayerChip(
          icon: AppIcons.captions,
          label: formatDelay(_subtitleState.delay),
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
          onReset: () => _tools.setRepeat(false),
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
            switch (_error) {
              PlayerError.openFile => l.openFileFailed,
              PlayerError.playbackCommand => l.playbackCommandFailed,
              null => l.playbackFailed,
            },
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
