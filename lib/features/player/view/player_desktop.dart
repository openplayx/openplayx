part of 'player_page.dart';

/// Desktop layout (Windows / macOS / Linux), design §3.
extension _DesktopPlayer on PlayerPageState {
  Widget _desktopBody() => LayoutBuilder(
    builder: (context, box) {
      final settingsOpen = _panel == PlayerPanel.settings;
      // Wide windows dock the panel beside the video (it keeps showing the
      // whole picture); narrow ones float it over the video.
      final docked = box.maxWidth >= 900;
      final panelWidth = math.min(360.0, box.maxWidth);
      return Row(
        children: [
          Expanded(
            child: MouseRegion(
              cursor: _controlsVisible || _name == null
                  ? MouseCursor.defer
                  : SystemMouseCursors.none,
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
                    _desktopVideoArea(),
                    ..._statusLayers(),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _chrome(_desktopTopBar()),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _chrome(
                        ValueListenableBuilder<PlayerSnapshot>(
                          valueListenable: _backend,
                          builder: (context, value, _) =>
                              _desktopBottomBar(value),
                        ),
                      ),
                    ),
                    if (_panel == PlayerPanel.tracks ||
                        _panel == PlayerPanel.speed ||
                        _panel == PlayerPanel.sleep ||
                        _panel == PlayerPanel.help ||
                        (settingsOpen && !docked))
                      Positioned.fill(
                        child: GestureDetector(
                          key: const Key('panel-barrier'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _closePanel,
                        ),
                      ),
                    if (settingsOpen && !docked)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        width: panelWidth,
                        child: _settingsSidePanel(panelWidth),
                      )
                    else if (_panel != PlayerPanel.none && !settingsOpen)
                      _desktopPopover(),
                  ],
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.panel),
            curve: Curves.easeOutCubic,
            width: settingsOpen && docked ? 360 : 0,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: 360,
                maxWidth: 360,
                child: settingsOpen && docked
                    ? _settingsSidePanel(360)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      );
    },
  );

  /// Video with mouse handling: click pauses, double click toggles full
  /// screen, wheel changes volume or seeks, right click opens the menu.
  Widget _desktopVideoArea() => ShadContextMenuRegion(
    items: _contextMenuItems(),
    constraints: const BoxConstraints(minWidth: 240),
    child: Listener(
      // Track queries can stall VLCKit while it starts or pauses, so they
      // run only on demand: when the menu that lists them opens.
      onPointerDown: (event) {
        if (event.buttons == kSecondaryButton && _enabled) {
          unawaited(_loadTracks());
        }
      },
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent || !_enabled) return;
        final dy = event.scrollDelta.dy;
        final dx = event.scrollDelta.dx;
        final shift = HardwareKeyboard.instance.isShiftPressed;
        if (dx.abs() > dy.abs() || shift) {
          final delta = dx.abs() > dy.abs() ? dx : dy;
          _jump(delta > 0 ? _prefs.extraShortJump : -_prefs.extraShortJump);
        } else if (dy != 0) {
          unawaited(
            _setVolume(
              _backend.value.volume +
                  (dy < 0 ? _prefs.volumeStep : -_prefs.volumeStep),
            ),
          );
        }
      },
      child: GestureDetector(
        key: const Key('video-gestures'),
        behavior: HitTestBehavior.opaque,
        onTap: _locked
            ? null
            : () {
                if (_panel != PlayerPanel.none) {
                  _closePanel();
                } else if (_prefs.clickToPause && _enabled) {
                  _togglePlayback();
                } else {
                  _toggleControls();
                }
              },
        onDoubleTap: _locked || _mobileDisplay || !_window.isSupported
            ? null
            : () => unawaited(_setFullscreen(!_fullscreen)),
        onLongPressStart: _locked ? null : (_) => _startBoost(),
        onLongPressEnd: (_) => _endBoost(),
        onLongPressCancel: _endBoost,
        child: _videoLayer(),
      ),
    ),
  );

  Widget _desktopTopBar() => Builder(
    builder: (context) {
      if (_pip.active) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: PlayerStyle.fg, fontSize: 13),
                ),
              ),
              PlayerIconButton(
                tooltip: l.close,
                icon: AppIcons.close,
                onPressed: _exitPlayback,
              ),
            ],
          ),
        );
      }
      // Align with the native traffic lights (centred ~14pt from the top)
      // and start after them (~80pt wide).
      final windowButtons = _reservesWindowButtons(context);
      return Container(
        padding:
            (windowButtons
                    ? const EdgeInsets.only(left: 80, right: 12, bottom: 24)
                    : const EdgeInsets.fromLTRB(12, 6, 12, 24))
                .add(_insets.copyWith(bottom: 0)),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xA8000000), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            if (widget.showBack) ...[
              PlayerIconButton(
                tooltip: l.back,
                icon: AppIcons.back,
                onPressed: _closing ? null : _exitPlayback,
                size: windowButtons ? 28 : 40,
                iconSize: windowButtons ? 16 : 20,
              ),
              const SizedBox(width: 6),
            ] else
              SizedBox(height: windowButtons ? 28 : 40),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PlayerStyle.fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      shadows: PlayerStyle.shadow,
                    ),
                  ),
                  if (_subtitle != null)
                    Text(
                      _subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PlayerStyle.muted,
                        fontSize: 12.5,
                        shadows: PlayerStyle.shadow,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Wrap(spacing: 8, children: _statusChips()),
            const SizedBox(width: 4),
            if (_canPictureInPicture) _pictureInPictureButton(),
            PlayerIconButton(
              tooltip: l.morePlaybackSettings,
              icon: AppIcons.more,
              onPressed: _name == null
                  ? null
                  : () => _openPanel(PlayerPanel.settings),
            ),
          ],
        ),
      );
    },
  );

  Widget _desktopBottomBar(PlayerSnapshot value) {
    if (_pip.active) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PlayerIconButton(
              tooltip: value.status == PlaybackStatus.playing
                  ? l.pause
                  : l.play,
              icon: value.status == PlaybackStatus.playing
                  ? AppIcons.pause
                  : AppIcons.play,
              onPressed: _enabled ? _togglePlayback : null,
            ),
            _pictureInPictureButton(),
          ],
        ),
      );
    }
    final position = _shownPosition(value);
    final playing = value.status == PlaybackStatus.playing;
    return Container(
      key: const Key('player-control-bar'),
      padding: const EdgeInsets.fromLTRB(
        12,
        36,
        12,
        8,
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
          if (_advancedTools)
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                key: const Key('advanced-tools'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayerIconButton(
                    tooltip: l.plSnapshot,
                    icon: AppIcons.snapshot,
                    onPressed: _enabled && _backend.supportsSnapshot
                        ? () => _perform(PlayerAction.snapshot)
                        : null,
                    size: 36,
                    iconSize: 18,
                  ),
                  PlayerIconButton(
                    tooltip: _abTooltip,
                    icon: AppIcons.repeatOne,
                    active: _ab.phase != AbPhase.off,
                    onPressed: _seekable ? _advanceAb : null,
                    size: 36,
                    iconSize: 18,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _seekBar(value),
          ),
          LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 720;
              return Row(
                children: [
                  if (wide)
                    PlayerIconButton(
                      tooltip: l.rewind,
                      icon: AppIcons.rewind,
                      badge: '${_prefs.shortJump.inSeconds}',
                      onPressed: _seekable ? () => _skip(-10) : null,
                    ),
                  PlayerIconButton(
                    tooltip: playing ? l.pause : l.play,
                    icon: playing ? AppIcons.pause : AppIcons.play,
                    iconSize: 24,
                    onPressed: _enabled ? _togglePlayback : null,
                  ),
                  if (wide)
                    PlayerIconButton(
                      tooltip: l.forward,
                      icon: AppIcons.forward,
                      badge: '${_prefs.shortJump.inSeconds}',
                      onPressed: _seekable ? () => _skip(10) : null,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Tooltip(
                            message: l.plTimeTooltip,
                            child: GestureDetector(
                              key: const Key('playback-time'),
                              onTap: () => _update(
                                () => _showRemaining = !_showRemaining,
                              ),
                              onDoubleTap: _seekable ? _askJumpToTime : null,
                              child: Text(
                                _timeText(value, position),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: PlayerStyle.fg,
                                  fontSize: 13,
                                  fontFeatures: PlayerStyle.tabular,
                                  shadows: PlayerStyle.shadow,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(child: _readSpeedLabel(value)),
                      ],
                    ),
                  ),
                  _desktopVolume(value),
                  PlayerIconButton(
                    key: _tracksButtonKey,
                    tooltip: l.plTracks,
                    icon: AppIcons.captions,
                    active: _panel == PlayerPanel.tracks,
                    onPressed: _enabled
                        ? () => _openPanel(PlayerPanel.tracks)
                        : null,
                  ),
                  Tooltip(
                    key: _speedButtonKey,
                    message: l.playbackSpeed,
                    child: Semantics(
                      button: true,
                      label: l.playbackSpeed,
                      child: ShadButton.ghost(
                        enabled: _enabled,
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: PlayerStyle.fg,
                        onPressed: () => _openPanel(PlayerPanel.speed),
                        child: Text(
                          formatSpeed(_speed),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFeatures: PlayerStyle.tabular,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (wide)
                    PlayerIconButton(
                      tooltip: l.plSettingsAndEffects,
                      icon: AppIcons.effects,
                      active: _panel == PlayerPanel.settings,
                      onPressed: _enabled
                          ? () => _openPanel(PlayerPanel.settings)
                          : null,
                    ),
                  if (_window.isSupported)
                    PlayerIconButton(
                      tooltip: _fullscreen
                          ? l.plExitFullscreen
                          : l.plFullscreen,
                      icon: _fullscreen
                          ? AppIcons.exitFullscreen
                          : AppIcons.fullscreen,
                      onPressed: () => _setFullscreen(!_fullscreen),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String get _abTooltip => switch (_ab.phase) {
    AbPhase.off => l.plAbSetA,
    AbPhase.aSet => l.plAbSetB,
    AbPhase.looping => l.plAbClear,
  };

  /// Volume icon (click mutes) whose slider expands on hover (design D12).
  Widget _desktopVolume(PlayerSnapshot value) => _HoverExpand(
    builder: (expanded) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerIconButton(
          tooltip: l.playerVolume,
          icon: value.volume == 0 ? AppIcons.muted : AppIcons.volume,
          onPressed: _enabled ? _toggleMute : null,
        ),
        AnimatedSize(
          duration: AppMotion.duration(context, AppMotion.feedback),
          child: expanded && _enabled
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 96,
                      child: ShadSlider(
                        key: const Key('playback-volume'),
                        initialValue: value.volume.clamp(0, 100).toDouble(),
                        max: 100,
                        onChanged: (v) => unawaited(
                          _adjust(() => _backend.setVolume(v.round())),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${value.volume}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: PlayerStyle.fg,
                          fontSize: 12,
                          fontFeatures: PlayerStyle.tabular,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    ),
  );

  Widget _desktopPopover() {
    final bottom = 76 + _insets.bottom;
    final available = MediaQuery.sizeOf(context).width - 32;
    double fit(double width) => math.min(width, available);
    Widget content() => switch (_panel) {
      PlayerPanel.tracks => SizedBox(width: fit(520), child: _tracksContent()),
      PlayerPanel.speed => SizedBox(width: fit(300), child: _speedContent()),
      PlayerPanel.sleep => SizedBox(width: fit(260), child: _sleepContent()),
      PlayerPanel.help => SizedBox(width: fit(560), child: _helpContent()),
      _ => const SizedBox.shrink(),
    };
    final panel = PlayerGlass(
      key: Key('panel-${_panel.name}'),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.max(
            160,
            MediaQuery.sizeOf(context).height - bottom - 72,
          ),
        ),
        child: SingleChildScrollView(
          child: ValueListenableBuilder<PlayerSnapshot>(
            valueListenable: _backend,
            builder: (context, _, _) => content(),
          ),
        ),
      ),
    );
    if (_panel == PlayerPanel.help) return Center(child: panel);
    // Popovers open above the button that opened them (design D-4); the
    // others sit at the right edge.
    final anchorKey = switch (_panel) {
      PlayerPanel.tracks => _tracksButtonKey,
      PlayerPanel.speed => _speedButtonKey,
      _ => null,
    };
    final box = anchorKey?.currentContext?.findRenderObject() as RenderBox?;
    final width =
        switch (_panel) {
          PlayerPanel.tracks => fit(520),
          PlayerPanel.speed => fit(300),
          PlayerPanel.sleep => fit(260),
          _ => fit(300),
        } +
        18;
    final stackWidth = MediaQuery.sizeOf(context).width;
    if (box != null && box.hasSize) {
      final center = box.localToGlobal(box.size.center(Offset.zero)).dx;
      final left = (center - width / 2)
          .clamp(16.0, math.max(16.0, stackWidth - width - 16))
          .toDouble();
      return Positioned(left: left, bottom: bottom, child: panel);
    }
    return Positioned(right: 16 + _insets.right, bottom: bottom, child: panel);
  }

  Widget _settingsSidePanel(double width) => Container(
    key: const Key('panel-settings'),
    width: width,
    decoration: const BoxDecoration(
      color: PlayerStyle.glass,
      border: Border(left: BorderSide(color: PlayerStyle.glassStroke)),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: PlayerStyle.fg, fontSize: 13),
      child: SafeArea(
        left: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.plSettingsAndEffects,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PlayerIconButton(
                    tooltip: l.close,
                    icon: AppIcons.close,
                    onPressed: _closePanel,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _SegmentedTabs<SettingsTab>(
                values: SettingsTab.values,
                selected: _settingsTab,
                label: (tab) => switch (tab) {
                  SettingsTab.picture => l.plPicture,
                  SettingsTab.sync => l.plSync,
                  SettingsTab.info => l.plInfo,
                },
                modified: (tab) => switch (tab) {
                  SettingsTab.picture => !_frame.isDefault,
                  SettingsTab.sync =>
                    _audioState.delay != Duration.zero ||
                        _subtitleState.delay != Duration.zero,
                  SettingsTab.info => false,
                },
                onChanged: (tab) {
                  _update(() => _settingsTab = tab);
                  if (tab == SettingsTab.info) unawaited(_loadInfo());
                  if (tab == SettingsTab.sync) unawaited(_loadTracks());
                  _updateStatsPolling();
                },
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 16),
                child: ValueListenableBuilder<PlayerSnapshot>(
                  valueListenable: _backend,
                  builder: (context, _, _) => switch (_settingsTab) {
                    SettingsTab.picture => _frameContent(),
                    SettingsTab.sync => _syncContent(),
                    SettingsTab.info => _infoContent(),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  List<Widget> _contextMenuItems() {
    String? key(PlayerAction action) => playerShortcutLabel(action);
    ShadContextMenuItem item(
      String label,
      VoidCallback? onPressed, {
      IconData? icon,
      String? shortcut,
      bool checked = false,
      List<Widget> items = const [],
    }) => ShadContextMenuItem(
      leading: checked
          ? Icon(AppIcons.check, size: 16)
          : icon == null
          ? const SizedBox(width: 16)
          : Icon(icon, size: 16),
      trailing: shortcut == null
          ? (items.isEmpty ? null : Icon(AppIcons.next, size: 14))
          : Text(shortcut),
      enabled: items.isNotEmpty || onPressed != null,
      onPressed: onPressed,
      items: items,
      child: Text(label),
    );

    final playing = _backend.value.status == PlaybackStatus.playing;
    final enabled = _enabled;
    VoidCallback? run(PlayerAction action, [bool when = true]) =>
        enabled && when ? () => unawaited(_perform(action)) : null;
    return [
      item(
        playing ? l.pause : l.play,
        run(PlayerAction.togglePlay),
        icon: playing ? AppIcons.pause : AppIcons.play,
        shortcut: key(PlayerAction.togglePlay),
      ),
      item(
        l.plStop,
        run(PlayerAction.stop),
        icon: AppIcons.stop,
        shortcut: key(PlayerAction.stop),
      ),
      const Divider(height: 8),
      item(
        l.plMenuPlaybackControl,
        null,
        icon: AppIcons.speed,
        items: [
          item(
            l.plFaster,
            run(PlayerAction.faster),
            shortcut: key(PlayerAction.faster),
          ),
          item(
            l.plSlower,
            run(PlayerAction.slower),
            shortcut: key(PlayerAction.slower),
          ),
          item(
            l.plNormalSpeed,
            run(PlayerAction.normalSpeed),
            shortcut: key(PlayerAction.normalSpeed),
            checked: _speed == 1,
          ),
          item(
            l.plJumpToTime,
            run(PlayerAction.jumpToTime, _seekable),
            shortcut: key(PlayerAction.jumpToTime),
          ),
          item(
            l.plJumpForwardMedium,
            run(PlayerAction.jumpForwardMedium, _seekable),
            shortcut: key(PlayerAction.jumpForwardMedium),
          ),
          item(
            l.plJumpBackMedium,
            run(PlayerAction.jumpBackMedium, _seekable),
            shortcut: key(PlayerAction.jumpBackMedium),
          ),
          item(_abTooltip, enabled && _seekable ? _advanceAb : null),
          item(
            l.plSleepTimer,
            enabled ? () => _openPanel(PlayerPanel.sleep) : null,
            icon: AppIcons.sleep,
          ),
          item(
            _repeatOne ? l.plRepeatOne : l.plRepeatOff,
            run(PlayerAction.cycleRepeat),
            icon: AppIcons.repeatOne,
            shortcut: key(PlayerAction.cycleRepeat),
          ),
        ],
      ),
      item(
        l.plMenuAudio,
        null,
        icon: AppIcons.audio,
        items: [
          for (final track in _audioState.tracks)
            item(
              _audioName(track),
              enabled ? () => _selectAudio(track.id) : null,
              checked: _audioState.current == track.id,
            ),
          if (_audioState.tracks.isEmpty) item(l.noAudioTracks, null),
          item(
            l.plNextAudioTrack,
            run(PlayerAction.nextAudioTrack),
            shortcut: key(PlayerAction.nextAudioTrack),
          ),
          item(
            l.plMute,
            run(PlayerAction.mute),
            shortcut: key(PlayerAction.mute),
          ),
          if (_backend.supportsDelays)
            item(
              '${l.plAudioDelay}  ${formatDelay(_audioState.delay)}',
              enabled ? _openSync : null,
            ),
        ],
      ),
      item(
        l.plMenuVideo,
        null,
        icon: AppIcons.movie,
        items: [
          if (_window.isSupported)
            item(
              _fullscreen ? l.plExitFullscreen : l.plFullscreen,
              () => _setFullscreen(!_fullscreen),
              shortcut: key(PlayerAction.toggleFullscreen),
            ),
          item(
            l.plFitMode,
            null,
            items: [
              for (final mode in VideoFitMode.values)
                item(
                  _fitLabel(mode),
                  enabled ? () => _setFrame(_frame.copyWith(mode: mode)) : null,
                  checked: _frame.mode == mode,
                ),
            ],
          ),
          item(
            l.plAspectRatio,
            null,
            items: [
              for (var i = 0; i < videoAspectRatios.length; i++)
                item(
                  videoAspectLabels[i] ?? l.plAspectDefault,
                  enabled
                      ? () => _setFrame(_frame.copyWith(aspectIndex: i))
                      : null,
                  checked: _frame.aspectIndex == i,
                ),
            ],
          ),
          item(
            l.plZoom,
            null,
            items: [
              for (final zoom in videoZoomSteps)
                item(
                  _zoomLabel(zoom),
                  enabled ? () => _setFrame(_frame.copyWith(zoom: zoom)) : null,
                  checked: _frame.zoom == zoom,
                ),
            ],
          ),
          item(
            l.videoRotation,
            null,
            items: [
              for (var turns = 0; turns < 4; turns++)
                item(
                  turns == 0 ? l.rotationOriginal : '${turns * 90}°',
                  enabled
                      ? () => _update(() => _videoQuarterTurns = turns)
                      : null,
                  checked: _videoQuarterTurns == turns,
                ),
            ],
          ),
          if (_backend.supportsSnapshot)
            item(
              l.plSnapshot,
              run(PlayerAction.snapshot),
              icon: AppIcons.snapshot,
              shortcut: key(PlayerAction.snapshot),
            ),
        ],
      ),
      item(
        l.plMenuSubtitle,
        null,
        icon: AppIcons.captions,
        items: [
          item(
            l.subtitleOff,
            enabled ? _subtitleOff : null,
            checked: _subtitleState.isOff,
          ),
          for (final (index, group) in [
            _subtitleState.embedded,
            _subtitleState.external,
            _subtitleState.recognized,
          ].indexed)
            if (group.isNotEmpty) ...[
              if (index > 0) ...[
                const Divider(height: 8),
                item(
                  index == 1 ? l.externalSubtitles : l.recognizedSubtitles,
                  null,
                ),
              ],
              for (final option in group)
                item(
                  _subtitleName(option),
                  enabled ? () => _chooseSubtitle(option) : null,
                  checked: _subtitleState.isSelected(option),
                ),
            ],
          if (_backend.supportsExternalSubtitles)
            item(
              l.plLoadSubtitle,
              enabled ? _addSubtitleFile : null,
              icon: AppIcons.addSubtitle,
            ),
          if (_backend.supportsDelays)
            item(
              '${l.plSubtitleDelay}  ${formatDelay(_subtitleState.delay)}',
              enabled ? _openSync : null,
            ),
        ],
      ),
      item(
        l.plMenuView,
        null,
        icon: AppIcons.preferences,
        items: [
          item(
            l.plAdvancedTools,
            () => _update(() => _advancedTools = !_advancedTools),
            checked: _advancedTools,
          ),
          if (_backend.supportsMediaInfo)
            item(l.plStatsOverlay, _toggleStatsOverlay, checked: _statsOverlay),
          item(
            l.plSettingsAndEffects,
            enabled ? () => _openPanel(PlayerPanel.settings) : null,
          ),
          item(
            l.plShortcuts,
            () => _openPanel(PlayerPanel.help),
            icon: AppIcons.keyboard,
            shortcut: key(PlayerAction.shortcutHelp),
          ),
        ],
      ),
      const Divider(height: 8),
      if (_backend.supportsSnapshot)
        item(
          l.plSnapshot,
          run(PlayerAction.snapshot),
          icon: AppIcons.snapshot,
          shortcut: key(PlayerAction.snapshot),
        ),
      if (_backend.supportsMediaInfo)
        item(
          l.plMediaInfo,
          enabled
              ? () {
                  _settingsTab = SettingsTab.info;
                  _openPanel(PlayerPanel.settings);
                }
              : null,
          icon: AppIcons.info,
        ),
      item(
        l.plSettingsAndEffects,
        enabled
            ? () {
                _settingsTab = SettingsTab.picture;
                _openPanel(PlayerPanel.settings);
              }
            : null,
        icon: AppIcons.settings,
      ),
      item(
        l.openFile,
        () => unawaited(openFile()),
        icon: AppIcons.openFile,
        shortcut: key(PlayerAction.openFile),
      ),
    ];
  }
}

/// Reports whether the pointer is over [builder]'s child.
class _HoverExpand extends StatefulWidget {
  const _HoverExpand({required this.builder});
  final Widget Function(bool expanded) builder;
  @override
  State<_HoverExpand> createState() => _HoverExpandState();
}

class _HoverExpandState extends State<_HoverExpand> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: widget.builder(_hover),
  );
}

/// Equal-width segmented tabs for the settings panel (design §3.5).
class _SegmentedTabs<T> extends StatelessWidget {
  const _SegmentedTabs({
    required this.values,
    required this.selected,
    required this.label,
    required this.modified,
    required this.onChanged,
  });
  final List<T> values;
  final T selected;
  final String Function(T) label;

  /// Tabs with changed settings carry an accent dot (design §3.5).
  final bool Function(T) modified;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0x0FFFFFFF),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      children: [
        for (final value in values)
          Expanded(
            child: Semantics(
              button: true,
              selected: value == selected,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(value),
                child: Container(
                  height: 28,
                  alignment: Alignment.center,
                  decoration: value == selected
                      ? BoxDecoration(
                          color: const Color(0x1FFFFFFF),
                          borderRadius: BorderRadius.circular(7),
                        )
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label(value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: value == selected
                                ? PlayerStyle.fg
                                : PlayerStyle.muted,
                            fontWeight: value == selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (modified(value))
                        Container(
                          key: Key('tab-modified-$value'),
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(left: 5, bottom: 6),
                          decoration: BoxDecoration(
                            color: PlayerStyle.accent(context),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
