part of 'player_page.dart';

/// Mobile gesture bookkeeping (design §4.3). Lives outside the state class
/// so the layout extension can update it.
class _MobileGestures {
  // Double-tap seeking: accumulated jump and the side it happened on.
  int tapSeekSeconds = 0;
  int tapSide = 0;
  Offset? doubleTapAt;

  // One-finger drag: undecided until it passes the slop.
  Offset? dragStart;
  Axis? dragAxis;
  bool dragLeftHalf = false;
  Duration dragFrom = Duration.zero;
  Duration? seekTarget;
  double levelFrom = 0;

  // Pinch.
  double pinchFrom = 1;
  bool pinching = false;

  // Multi-finger taps (two: play/pause, three: snapshot).
  final pointers = <int, Offset>{};
  int maxPointers = 0;
  bool moved = false;
  DateTime? downAt;
  DateTime? multiTouchAt;

  _Feedback feedback = _Feedback.none;
  double level = 0;
}

extension _MobilePlayer on PlayerPageState {
  _MobileGestures get _g => _gestures;

  Widget _mobileBody() {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    return Listener(
      onPointerDown: _onTouchDown,
      onPointerMove: _onTouchMove,
      onPointerUp: _onTouchUp,
      onPointerCancel: (event) {
        _g.pointers.remove(event.pointer);
        _pointerDown = _g.pointers.isNotEmpty;
        _endBoost();
        _scheduleHide();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            key: const Key('video-gestures'),
            behavior: HitTestBehavior.opaque,
            onTap: _onVideoTap,
            onDoubleTapDown: (details) =>
                _g.doubleTapAt = details.localPosition,
            onDoubleTap: _locked ? null : _onDoubleTap,
            onLongPressStart: _locked ? null : (_) => _startBoost(),
            onLongPressMoveUpdate: _locked
                ? null
                : (details) {
                    if (details.offsetFromOrigin.dy < -48) _lockBoost();
                  },
            onLongPressEnd: (_) => _endBoost(),
            onLongPressCancel: _endBoost,
            onScaleStart: _locked ? null : _onScaleStart,
            onScaleUpdate: _locked ? null : _onScaleUpdate,
            onScaleEnd: _locked ? null : _onScaleEnd,
            child: _videoLayer(),
          ),
          if (!_pipVideoOnly) ..._statusLayers(),
          if (!_pipVideoOnly) ..._gestureFeedback(),
          if (!_locked && !_pipVideoOnly) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _chrome(_mobileTopBar(portrait: !landscape)),
            ),
            Positioned.fromRect(
              rect: landscape ? Offset.zero & size : _portraitVideoRect(size),
              child: _chrome(
                IgnorePointer(
                  ignoring: _name == null,
                  child: Center(
                    child: ValueListenableBuilder<PlayerSnapshot>(
                      valueListenable: _backend,
                      builder: (context, value, _) =>
                          _centerControls(value, compact: !landscape),
                    ),
                  ),
                ),
                opaque: false,
              ),
            ),
            if (landscape) ...[
              Positioned(
                left: 12 + _insets.left,
                top: 0,
                bottom: 0,
                child: _chrome(
                  Center(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0x4D000000),
                        shape: BoxShape.circle,
                      ),
                      child: PlayerIconButton(
                        tooltip: l.lockControls,
                        icon: AppIcons.unlock,
                        size: 44,
                        onPressed: _enabled ? _lock : null,
                      ),
                    ),
                  ),
                  opaque: false,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _chrome(
                  ValueListenableBuilder<PlayerSnapshot>(
                    valueListenable: _backend,
                    builder: (context, value, _) =>
                        _mobileBottomBar(value, landscape),
                  ),
                ),
              ),
            ] else
              // Portrait: title, progress and buttons stay below the picture.
              Positioned(
                top: _portraitVideoRect(size).bottom,
                left: 0,
                right: 0,
                bottom: 0,
                child: ValueListenableBuilder<PlayerSnapshot>(
                  valueListenable: _backend,
                  builder: (context, value, _) => _portraitPanel(value),
                ),
              ),
          ],
          if (_panel != PlayerPanel.none && !_pipVideoOnly)
            ..._mobileSheet(landscape),
          if (_locked && _showUnlock && !_pipVideoOnly)
            Positioned(
              left: 0,
              right: 0,
              bottom: 40 + _insets.bottom,
              child: Center(
                child: _SlideToUnlock(
                  label: l.plSlideToUnlock,
                  semanticLabel: l.unlockControls,
                  onUnlock: _unlock,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---- Raw pointers: multi-finger taps -----------------------------------

  void _onTouchDown(PointerDownEvent event) {
    _playerFocus.requestFocus();
    _pointerDown = true;
    _hideTimer?.cancel();
    if (_g.pointers.isEmpty) {
      _g.maxPointers = 0;
      _g.moved = false;
      _g.downAt = DateTime.now();
    }
    _g.pointers[event.pointer] = event.position;
    _g.maxPointers = math.max(_g.maxPointers, _g.pointers.length);
    if (_g.maxPointers > 1) _g.multiTouchAt = DateTime.now();
  }

  void _onTouchMove(PointerMoveEvent event) {
    final start = _g.pointers[event.pointer];
    if (start != null && (event.position - start).distance > 18) {
      _g.moved = true;
    }
  }

  void _onTouchUp(PointerUpEvent event) {
    _g.pointers.remove(event.pointer);
    if (_g.pointers.isNotEmpty) return;
    _pointerDown = false;
    _endBoost();
    final quick =
        _g.downAt != null &&
        DateTime.now().difference(_g.downAt!) <
            const Duration(milliseconds: 350);
    if (!_locked && quick && !_g.moved && _panel == PlayerPanel.none) {
      if (_g.maxPointers == 2) {
        _togglePlayback();
      } else if (_g.maxPointers == 3) {
        unawaited(_perform(PlayerAction.snapshot));
      }
    }
    _scheduleHide();
  }

  bool get _recentMultiTouch =>
      _g.multiTouchAt != null &&
      DateTime.now().difference(_g.multiTouchAt!) <
          const Duration(milliseconds: 600);

  // ---- Taps --------------------------------------------------------------

  void _onVideoTap() {
    if (_recentMultiTouch) return;
    if (_locked) {
      _update(() => _showUnlock = true);
      _armUnlockHint();
      return;
    }
    if (_panel != PlayerPanel.none) {
      _closePanel();
      return;
    }
    _toggleControls();
  }

  void _armUnlockHint() {
    _unlockTimer?.cancel();
    _unlockTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _update(() => _showUnlock = false);
    });
  }

  void _onDoubleTap() {
    if (_recentMultiTouch || _panel != PlayerPanel.none) return;
    final at = _g.doubleTapAt;
    final width = MediaQuery.sizeOf(context).width;
    if (at == null || width <= 0) return;
    final third = at.dx / width;
    if (third > 1 / 3 && third < 2 / 3) {
      _togglePlayback();
      return;
    }
    if (!_seekable) return;
    final side = third <= 1 / 3 ? -1 : 1;
    final step = _prefs.doubleTapJump.inSeconds;
    _update(() {
      if (_g.tapSide != side) _g.tapSeekSeconds = 0;
      _g.tapSide = side;
      _g.tapSeekSeconds += step;
    });
    _jump(Duration(seconds: side * step), feedback: false);
    _tapSeekTimer?.cancel();
    _tapSeekTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        _update(() {
          _g.tapSeekSeconds = 0;
          _g.tapSide = 0;
        });
      }
    });
  }

  // ---- Drag and pinch ----------------------------------------------------

  void _onScaleStart(ScaleStartDetails details) {
    _g.dragStart = details.localFocalPoint;
    _g.dragAxis = null;
    _g.pinching = details.pointerCount > 1;
    _g.pinchFrom = _frame.zoom;
    _g.dragLeftHalf =
        details.localFocalPoint.dx < MediaQuery.sizeOf(context).width / 2;
    _g.dragFrom = _position;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_panel != PlayerPanel.none || !_enabled) return;
    if (details.pointerCount > 1) {
      _g.pinching = true;
      if ((details.scale - 1).abs() > 0.04) {
        _update(
          () => _frame = _frame.copyWith(
            zoom: clampPinchZoom(_g.pinchFrom * details.scale),
          ),
        );
      }
      return;
    }
    if (_g.pinching || _g.dragStart == null) return;
    final delta = details.localFocalPoint - _g.dragStart!;
    final size = MediaQuery.sizeOf(context);
    if (_g.dragAxis == null) {
      if (delta.distance < 16) return;
      _g.dragAxis = delta.dx.abs() > delta.dy.abs()
          ? Axis.horizontal
          : Axis.vertical;
      _g.levelFrom = _g.dragLeftHalf
          ? _brightness
          : _backend.value.volume / 100;
      _hideTimer?.cancel();
    }
    if (_g.dragAxis == Axis.horizontal) {
      if (!_seekable) return;
      final duration = _backend.value.duration;
      // A full-width swipe covers 90 s (or the whole of a shorter media).
      final span = duration < const Duration(seconds: 90)
          ? duration
          : const Duration(seconds: 90);
      final offset = span * (delta.dx / size.width);
      var target = _g.dragFrom + offset;
      if (target.isNegative) target = Duration.zero;
      if (target > duration) target = duration;
      _update(() {
        _g.seekTarget = target;
        _g.feedback = _Feedback.seek;
      });
    } else {
      final level = _clamp01(_g.levelFrom - delta.dy / (size.height * 0.7));
      if (_g.dragLeftHalf) {
        _update(() {
          _brightness = math.max(0.15, level);
          _g.feedback = _Feedback.brightness;
          _g.level = level;
        });
      } else {
        _update(() {
          _g.feedback = _Feedback.volume;
          _g.level = level;
        });
        unawaited(_adjust(() => _backend.setVolume((level * 100).round())));
      }
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final target = _g.seekTarget;
    if (_g.feedback == _Feedback.seek && target != null) {
      unawaited(_seekAbsolute(target));
    }
    _g
      ..dragStart = null
      ..dragAxis = null
      ..seekTarget = null
      ..pinching = false;
    if (_g.feedback != _Feedback.none) {
      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted && _g.dragStart == null) {
          _update(() => _g.feedback = _Feedback.none);
        }
      });
    }
    _scheduleHide();
  }

  List<Widget> _gestureFeedback() {
    final widgets = <Widget>[];
    if (_g.tapSeekSeconds != 0) {
      final left = _g.tapSide < 0;
      widgets.add(
        Positioned(
          top: 0,
          bottom: 0,
          left: left ? 0 : null,
          right: left ? null : 0,
          width: MediaQuery.sizeOf(context).width * 0.36,
          child: IgnorePointer(
            child: Container(
              key: const Key('double-tap-ripple'),
              decoration: BoxDecoration(
                color: const Color(0x1FFFFFFF),
                borderRadius: left
                    ? const BorderRadius.horizontal(right: Radius.circular(400))
                    : const BorderRadius.horizontal(left: Radius.circular(400)),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    left ? AppIcons.rewindOsd : AppIcons.forwardOsd,
                    color: PlayerStyle.fg,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.plJumpSeconds('${left ? '-' : '+'}${_g.tapSeekSeconds}'),
                    style: const TextStyle(
                      color: PlayerStyle.fg,
                      fontWeight: FontWeight.w600,
                      fontFeatures: PlayerStyle.tabular,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    switch (_g.feedback) {
      case _Feedback.seek:
        final target = _g.seekTarget ?? Duration.zero;
        final diff = target - _g.dragFrom;
        widgets.add(
          Center(
            child: IgnorePointer(
              child: PlayerGlass(
                key: const Key('seek-feedback'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatTime(target),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        fontFeatures: PlayerStyle.tabular,
                      ),
                    ),
                    Text(
                      '${diff.isNegative ? '-' : '+'}${formatTime(diff.abs())}',
                      style: TextStyle(
                        color: PlayerStyle.accent(context),
                        fontFeatures: PlayerStyle.tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      case _Feedback.volume:
      case _Feedback.brightness:
        final volume = _g.feedback == _Feedback.volume;
        widgets.add(
          Positioned(
            top: 0,
            bottom: 0,
            left: volume ? null : 64 + _insets.left,
            right: volume ? 64 + _insets.right : null,
            child: Center(
              child: PlayerLevelBar(
                key: Key(volume ? 'volume-feedback' : 'brightness-feedback'),
                icon: volume ? AppIcons.volume : AppIcons.brightness,
                level: _g.level,
              ),
            ),
          ),
        );
      case _Feedback.none:
        break;
    }
    return widgets;
  }

  // ---- Chrome ------------------------------------------------------------

  Widget _mobileTopBar({required bool portrait}) => Container(
    padding: const EdgeInsets.fromLTRB(
      8,
      4,
      8,
      28,
    ).add(_insets.copyWith(bottom: 0)),
    decoration: portrait
        ? null
        : const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xA8000000), Colors.transparent],
            ),
          ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (widget.showBack)
              PlayerIconButton(
                tooltip: l.back,
                icon: AppIcons.collapsePlayer,
                size: 44,
                iconSize: 24,
                onPressed: _closing ? null : _exitPlayback,
              )
            else
              const SizedBox(height: 44, width: 8),
            const SizedBox(width: 4),
            Expanded(
              // Portrait shows the title under the picture instead.
              child: portrait
                  ? const SizedBox.shrink()
                  : Text.rich(
                      TextSpan(
                        text: _title,
                        children: [
                          if (_subtitle != null)
                            TextSpan(
                              text: ' · $_subtitle',
                              style: const TextStyle(
                                color: PlayerStyle.muted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PlayerStyle.fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        shadows: PlayerStyle.shadow,
                      ),
                    ),
            ),
            if (_canPictureInPicture) _pictureInPictureButton(),
            PlayerIconButton(
              tooltip: l.morePlaybackSettings,
              icon: AppIcons.more,
              size: 44,
              onPressed: _enabled ? () => _openPanel(PlayerPanel.more) : null,
            ),
            if (widget.onAssistantPressed != null)
              PlayerIconButton(
                tooltip: l.aiAssistant,
                icon: AppIcons.assistant,
                size: 44,
                onPressed: widget.onAssistantPressed,
              ),
          ],
        ),
        if (_statusChips().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: _statusChips(),
            ),
          ),
      ],
    ),
  );

  Widget _centerControls(PlayerSnapshot value, {bool compact = false}) {
    final playing = value.status == PlaybackStatus.playing;
    Widget round(Widget child, double size) => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0x52000000),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: child,
    );
    final step = '${_prefs.doubleTapJump.inSeconds}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        round(
          PlayerIconButton(
            tooltip: l.rewind,
            icon: AppIcons.rewind,
            badge: step,
            size: 50,
            iconSize: 26,
            onPressed: _seekable ? () => _jump(-_prefs.doubleTapJump) : null,
          ),
          52,
        ),
        SizedBox(width: compact ? 32 : 40),
        round(
          PlayerIconButton(
            tooltip: playing ? l.pause : l.play,
            icon: playing ? AppIcons.pause : AppIcons.play,
            size: 64,
            iconSize: 32,
            onPressed: _enabled ? _togglePlayback : null,
            // Long press stops (design P07).
            onLongPress: () => unawaited(_perform(PlayerAction.stop)),
          ),
          compact ? 60 : 68,
        ),
        SizedBox(width: compact ? 32 : 40),
        round(
          PlayerIconButton(
            tooltip: l.forward,
            icon: AppIcons.forward,
            badge: step,
            size: 50,
            iconSize: 26,
            onPressed: _seekable ? () => _jump(_prefs.doubleTapJump) : null,
          ),
          52,
        ),
      ],
    );
  }

  /// Size presets the ratio button cycles through (VLC Android order).
  static const _framePresets = [
    VideoFrameSettings(),
    VideoFrameSettings(mode: VideoFitMode.fill),
    VideoFrameSettings(aspectIndex: 1),
    VideoFrameSettings(aspectIndex: 2),
    VideoFrameSettings(mode: VideoFitMode.original),
  ];

  void _cycleFramePreset() {
    final index = _framePresets.indexOf(_frame);
    _setFrame(_framePresets[(index + 1) % _framePresets.length]);
  }

  /// Landscape bottom bar over the picture (design M-1).
  Widget _mobileBottomBar(PlayerSnapshot value, bool landscape) => Container(
    key: const Key('player-control-bar'),
    padding: const EdgeInsets.fromLTRB(
      40,
      28,
      40,
      4,
    ).add(_insets.copyWith(top: 0)),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Color(0xB8000000)],
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _timeRow(value),
        Row(children: [..._primaryButtons(), _rotationButton()]),
      ],
    ),
  );

  Widget _barButton(
    String label,
    String tooltip,
    IconData? icon,
    VoidCallback? onTap, {
    VoidCallback? onLongPress,
    String? text,
    int iconTurns = 0,
  }) => Expanded(
    child: Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        enabled: onTap != null,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          onLongPress: onTap == null ? null : onLongPress,
          child: SizedBox(
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (text != null)
                  Text(
                    text,
                    style: TextStyle(
                      color: onTap == null ? PlayerStyle.muted : PlayerStyle.fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: PlayerStyle.tabular,
                    ),
                  )
                else
                  RotatedBox(
                    quarterTurns: iconTurns,
                    child: Icon(
                      icon,
                      size: 21,
                      color: onTap == null ? PlayerStyle.muted : PlayerStyle.fg,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PlayerStyle.muted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  /// Time row: current position, seek bar, remaining/total (tap toggles).
  Widget _timeRow(PlayerSnapshot value, {bool readSpeed = true}) {
    final duration = value.duration.inMilliseconds.toDouble();
    final position = _shownPosition(value);
    const timeStyle = TextStyle(
      color: PlayerStyle.fg,
      fontSize: 13,
      fontFeatures: PlayerStyle.tabular,
      shadows: PlayerStyle.shadow,
    );
    final at = Duration(milliseconds: position.round());
    final current = formatClock(at, value.duration);
    final rest = duration <= 0
        ? '--:--'
        : _showRemaining
        ? '-${formatClock(value.duration - at, value.duration)}'
        : formatClock(value.duration, value.duration);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (readSpeed) _readSpeedLabel(value),
        Row(
          children: [
            Text(current, style: timeStyle),
            const SizedBox(width: 10),
            Expanded(child: _seekBar(value, lane: 32)),
            const SizedBox(width: 10),
            GestureDetector(
              key: const Key('playback-time'),
              onTap: () => _update(() => _showRemaining = !_showRemaining),
              child: Text(rest, style: timeStyle),
            ),
          ],
        ),
      ],
    );
  }

  /// Shared controls in their reading order; rotation follows these in landscape.
  List<Widget> _primaryButtons() => [
    _barButton(
      l.audioTrack,
      l.audioTrack,
      AppIcons.audio,
      _enabled ? () => _openPanel(PlayerPanel.audio) : null,
    ),
    _barButton(
      l.subtitleTrack,
      l.subtitleTrack,
      AppIcons.captions,
      _enabled ? () => _openPanel(PlayerPanel.subtitles) : null,
    ),
    _barButton(
      _frame.isDefault
          ? l.plFitBest
          : videoAspectLabels[_frame.aspectIndex] ?? _fitLabel(_frame.mode),
      l.plAspectRatio,
      AppIcons.aspect,
      _enabled ? _cycleFramePreset : null,
      onLongPress: () => _openPanel(PlayerPanel.frame),
    ),
    _speedButton(),
  ];

  Widget _rotationButton() => _barButton(
    _rotateLabel,
    _rotateLabel,
    AppIcons.screenOrientation,
    _enabled && !_changingDisplay ? _toggleOrientation : null,
    iconTurns: _targetOrientation == PlayerScreenOrientation.landscape ? 1 : 0,
  );

  Widget _speedButton() => _barButton(
    l.plSpeedShort,
    l.playbackSpeed,
    null,
    _enabled ? () => _openPanel(PlayerPanel.speed) : null,
    text: formatSpeed(_speed),
  );

  /// Portrait controls below the picture (design M-7).
  Widget _portraitPanel(PlayerSnapshot value) => ColoredBox(
    color: AppSemanticColors.playerSurface,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 12 + _insets.bottom),
      child: Column(
        key: const Key('player-control-bar'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PlayerStyle.fg,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          // File name (truncated) and read speed share one line.
          Row(
            children: [
              Expanded(
                child: Text(
                  _subtitle ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PlayerStyle.muted,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _readSpeedLabel(value),
            ],
          ),
          const SizedBox(height: 8),
          _timeRow(value, readSpeed: false),
          const SizedBox(height: 12),
          Row(children: _primaryButtons()),
          const SizedBox(height: 8),
          Row(
            children: [
              _barButton(
                l.plLockShort,
                l.lockControls,
                AppIcons.unlock,
                _enabled ? _lock : null,
              ),
              _barButton(
                l.plSleepShort,
                l.plSleepTimer,
                AppIcons.sleep,
                _enabled ? () => _openPanel(PlayerPanel.sleep) : null,
              ),
              if (_backend.supportsSnapshot)
                _barButton(
                  l.plSnapshot,
                  l.plSnapshot,
                  AppIcons.snapshot,
                  _enabled ? () => _perform(PlayerAction.snapshot) : null,
                )
              else
                const Spacer(),
              _rotationButton(),
            ],
          ),
        ],
      ),
    ),
  );

  // ---- Sheets ------------------------------------------------------------

  List<Widget> _mobileSheet(bool landscape) {
    if (_panel == PlayerPanel.alignment)
      return _mobileAlignmentSheet(landscape);
    Widget content() => switch (_panel) {
      PlayerPanel.more => _moreContent(),
      PlayerPanel.tracks => _tracksContent(),
      PlayerPanel.audio => _singleTrackContent(audio: true),
      PlayerPanel.subtitles => _singleTrackContent(audio: false),
      PlayerPanel.speed => _speedContent(),
      PlayerPanel.sleep => _sleepContent(),
      PlayerPanel.frame => _frameContent(),
      PlayerPanel.sync => _syncContent(),
      PlayerPanel.info => _infoContent(),
      PlayerPanel.help => _helpContent(),
      _ => _frameContent(),
    };
    var handleDrag = 0.0;
    final sheet = PlayerGlass(
      key: Key('panel-${_panel.name}'),
      radius: landscape
          ? const BorderRadius.horizontal(left: Radius.circular(20))
          : const BorderRadius.vertical(top: Radius.circular(20)),
      padding: EdgeInsets.fromLTRB(
        12,
        landscape ? 12 + _insets.top : 8,
        12 + (landscape ? _insets.right : 0),
        12 + _insets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!landscape)
            Semantics(
              button: true,
              label: l.close,
              child: GestureDetector(
                key: const Key('panel-handle'),
                behavior: HitTestBehavior.opaque,
                onTap: _closePanel,
                onVerticalDragStart: (_) => handleDrag = 0,
                onVerticalDragUpdate: (details) =>
                    handleDrag += details.delta.dy,
                onVerticalDragEnd: (details) {
                  if (handleDrag > 40 || (details.primaryVelocity ?? 0) > 300) {
                    _closePanel();
                  }
                },
                child: SizedBox(
                  height: 32,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0x4DFFFFFF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              // Panels show live values (position, read speed...).
              child: ValueListenableBuilder<PlayerSnapshot>(
                valueListenable: _backend,
                builder: (context, _, _) => content(),
              ),
            ),
          ),
        ],
      ),
    );
    final size = MediaQuery.sizeOf(context);
    return [
      Positioned.fill(
        child: GestureDetector(
          key: const Key('panel-barrier'),
          behavior: HitTestBehavior.opaque,
          onTap: _closePanel,
          child: const ColoredBox(color: Color(0x59000000)),
        ),
      ),
      if (landscape)
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: math.min(
            size.width * 0.6,
            _panel == PlayerPanel.tracks ? 560 : 380,
          ),
          child: sheet,
        )
      else
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: size.height * 0.7),
            child: sheet,
          ),
        ),
    ];
  }

  Widget _moreContent() {
    final accent = PlayerStyle.accent(context);
    Widget quick(
      IconData icon,
      String label,
      VoidCallback? onTap, {
      String? value,
      bool on = false,
    }) => Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: on
                  ? accent.withValues(alpha: 0.2)
                  : const Color(0x12FFFFFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(icon, size: 22, color: on ? accent : PlayerStyle.fg),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 11.5)),
                if (value != null)
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: accent,
                      fontFeatures: PlayerStyle.tabular,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final sleeping = _sleepAt != null || _sleepAtEnd;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            quick(
              AppIcons.speed,
              l.plSpeedShort,
              () => _openPanel(PlayerPanel.speed),
              value: _speed == 1 ? null : formatSpeed(_speed),
              on: _speed != 1,
            ),
            quick(
              AppIcons.sleep,
              l.plSleepShort,
              () => _openPanel(PlayerPanel.sleep),
              value: _sleepAt != null
                  ? formatTime(_sleepAt!.difference(DateTime.now()))
                  : _sleepAtEnd
                  ? l.plSleepEndOfItem
                  : null,
              on: sleeping,
            ),
            quick(AppIcons.lock, l.plLockShort, _lock),
            if (_backend.supportsSnapshot)
              quick(AppIcons.snapshot, l.plSnapshot, () {
                _closePanel();
                unawaited(_perform(PlayerAction.snapshot));
              }),
          ],
        ),
        PlayerSectionLabel(l.plMenuPlayback),
        PlayerMenuRow(
          icon: AppIcons.clock,
          label: l.plJumpToTime,
          chevron: true,
          height: 44,
          enabled: _seekable,
          onTap: () {
            _closePanel();
            unawaited(_askJumpToTime());
          },
        ),
        PlayerMenuRow(
          icon: AppIcons.repeatOne,
          label: l.plAbLoop,
          value: switch (_ab.phase) {
            AbPhase.off => l.plAbSetA,
            AbPhase.aSet => l.plAbSetB,
            AbPhase.looping => l.plAbClear,
          },
          height: 44,
          enabled: _seekable,
          onTap: _advanceAb,
        ),
        PlayerMenuRow(
          icon: AppIcons.repeat,
          label: l.plRepeatMode,
          value: _repeatOne ? l.plRepeatOne : l.plRepeatOff,
          height: 44,
          onTap: () => _perform(PlayerAction.cycleRepeat),
        ),
        PlayerSectionLabel(l.plPictureAndSound),
        PlayerMenuRow(
          icon: AppIcons.aspect,
          label: l.plPicture,
          value: _frame.isDefault
              ? l.plFitBest
              : videoAspectLabels[_frame.aspectIndex] ?? _fitLabel(_frame.mode),
          chevron: true,
          height: 44,
          onTap: () => _openPanel(PlayerPanel.frame),
        ),
        if (_backend.supportsDelays)
          PlayerMenuRow(
            icon: AppIcons.audio,
            label: l.plSync,
            value:
                '${formatDelay(_audioState.delay)} / ${formatDelay(_subtitleState.delay)}',
            chevron: true,
            height: 44,
            onTap: () => _openPanel(PlayerPanel.sync),
          ),
        if (_backend.supportsMediaInfo)
          PlayerMenuRow(
            icon: AppIcons.stats,
            label: l.plMediaInfo,
            chevron: true,
            height: 44,
            onTap: () => _openPanel(PlayerPanel.info),
          ),
      ],
    );
  }
}

/// Slide the knob to the right to unlock (design MG13). Screen readers get
/// a plain tap action instead.
class _SlideToUnlock extends StatefulWidget {
  const _SlideToUnlock({
    required this.label,
    required this.semanticLabel,
    required this.onUnlock,
  });
  final String label, semanticLabel;
  final VoidCallback onUnlock;
  @override
  State<_SlideToUnlock> createState() => _SlideToUnlockState();
}

class _SlideToUnlockState extends State<_SlideToUnlock> {
  static const _width = 260.0, _knob = 44.0;
  double _offset = 0;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.semanticLabel,
    onTap: widget.onUnlock,
    child: PlayerGlass(
      key: const Key('slide-to-unlock'),
      width: _width,
      padding: const EdgeInsets.all(4),
      radius: BorderRadius.circular(26),
      child: SizedBox(
        height: _knob,
        child: Stack(
          children: [
            Center(
              child: Text(
                widget.label,
                style: const TextStyle(color: PlayerStyle.muted),
              ),
            ),
            const Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Icon(
                AppIcons.chevronsRight,
                size: 18,
                color: PlayerStyle.muted,
              ),
            ),
            Positioned(
              left: _offset,
              child: GestureDetector(
                key: const Key('unlock-knob'),
                onHorizontalDragUpdate: (details) => setState(
                  () => _offset = (_offset + details.delta.dx).clamp(
                    0,
                    _width - _knob - 10,
                  ),
                ),
                onHorizontalDragEnd: (_) {
                  if (_offset > (_width - _knob) * 0.7) {
                    widget.onUnlock();
                  } else {
                    setState(() => _offset = 0);
                  }
                },
                child: Container(
                  width: _knob,
                  height: _knob,
                  decoration: const BoxDecoration(
                    color: PlayerStyle.fg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(AppIcons.lock, size: 20, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
