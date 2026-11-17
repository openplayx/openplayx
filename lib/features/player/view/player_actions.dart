part of 'player_page.dart';

/// Input entry: keys and the shared [PlayerAction] dispatch used by keys,
/// menus, buttons and gestures. Each action calls the matching controller
/// or view operation.
extension _PlayerActions on PlayerPageState {
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
    // Remote Back closes an open panel; otherwise the system handles it.
    if (key == LogicalKeyboardKey.goBack && _panel != PlayerPanel.none) {
      if (event is! KeyRepeatEvent) _closePanel();
      return KeyEventResult.handled;
    }
    // Separate Play and Pause keys (TV remotes) only ever go one way.
    if (key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause) {
      if (event is KeyRepeatEvent ||
          _locked ||
          !_enabled ||
          _panel != PlayerPanel.none) {
        return KeyEventResult.handled;
      }
      final playing = _backend.value.status == PlaybackStatus.playing;
      if (playing == (key == LogicalKeyboardKey.mediaPause)) {
        _showControls();
        unawaited(_perform(PlayerAction.togglePlay));
      }
      return KeyEventResult.handled;
    }
    final keyboard = HardwareKeyboard.instance;
    final apple = isApplePlatform;
    final action = resolvePlayerKey(
      key,
      shift: keyboard.isShiftPressed,
      alt: keyboard.isAltPressed,
      primary: apple ? keyboard.isMetaPressed : keyboard.isControlPressed,
      otherModifier: apple ? keyboard.isControlPressed : keyboard.isMetaPressed,
    );
    if (action == null) return KeyEventResult.ignored;
    // An open panel keeps arrows and letters for itself; Escape closes it.
    if (_panel != PlayerPanel.none) return KeyEventResult.ignored;
    if (action == PlayerAction.openFile) {
      if (event is! KeyRepeatEvent) unawaited(openFile());
      return KeyEventResult.handled;
    }
    if (_locked || !_enabled) return KeyEventResult.handled;
    if (event is KeyRepeatEvent && isTogglePlayerAction(action)) {
      return KeyEventResult.handled;
    }
    if (action == PlayerAction.toggleControls) {
      _toggleControls();
      return KeyEventResult.handled;
    } else {
      _showControls();
      unawaited(_perform(action));
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
        await _setSubtitleDelay(_subtitleState.delay + _prefs.delayStep);
      case PlayerAction.subtitleDelayDown:
        await _setSubtitleDelay(_subtitleState.delay - _prefs.delayStep);
      case PlayerAction.audioDelayUp:
        await _setAudioDelay(_audioState.delay + _prefs.delayStep);
      case PlayerAction.audioDelayDown:
        await _setAudioDelay(_audioState.delay - _prefs.delayStep);
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
        final repeatOne = _tools.toggleRepeat();
        _flash(
          repeatOne ? AppIcons.repeatOne : AppIcons.repeat,
          repeatOne ? l.plRepeatOne : l.plRepeatOff,
        );
      case PlayerAction.openFile:
        await openFile();
      case PlayerAction.shortcutHelp:
        _openPanel(PlayerPanel.help);
    }
  }
}
