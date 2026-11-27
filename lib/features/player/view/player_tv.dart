part of 'player_page.dart';

extension _TvPlayer on PlayerPageState {
  /// Used by Android's system Back as well as remote key events.
  void _tvBack() {
    if (_drag != null) {
      _update(() => _drag = null);
      _scheduleHide();
    } else if (_panel != PlayerPanel.none) {
      _closePanel();
    } else if (_controlsVisible && _name != null) {
      _hideTimer?.cancel();
      _update(() => _controlsVisible = false);
      _playerFocus.requestFocus();
    } else {
      unawaited(_exitPlayback());
    }
  }

  KeyEventResult _handleTvKey(KeyEvent event) {
    if (!widget.active ||
        ModalRoute.of(context)?.isCurrent != true ||
        event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (event is! KeyRepeatEvent) _tvBack();
      return KeyEventResult.handled;
    }
    if (_openPanels > 0) return KeyEventResult.ignored;
    if ({
      LogicalKeyboardKey.mediaPlayPause,
      LogicalKeyboardKey.mediaPlay,
      LogicalKeyboardKey.mediaPause,
    }.contains(key)) {
      if (event is KeyRepeatEvent || !_enabled) return KeyEventResult.handled;
      final playing = _backend.value.status == PlaybackStatus.playing;
      if (key == LogicalKeyboardKey.mediaPlayPause ||
          key == LogicalKeyboardKey.mediaPlay && !playing ||
          key == LogicalKeyboardKey.mediaPause && playing) {
        _togglePlayback();
      }
      _showControls();
      return KeyEventResult.handled;
    }
    final direction = switch (key) {
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      _ => null,
    };
    final activate = {
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.gameButtonA,
    }.contains(key);
    if (direction == null && !activate) return KeyEventResult.ignored;
    if (!_controlsVisible) {
      _showControls();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) _tvFocus['play']!.requestFocus();
      });
      return KeyEventResult.handled;
    }
    _scheduleHide();
    if (direction != null) {
      if (_panel == PlayerPanel.none &&
          _tvFocus['seek']!.hasFocus &&
          (direction == TraversalDirection.left ||
              direction == TraversalDirection.right)) {
        if (_seekable) {
          _hideTimer?.cancel();
          final step = (event is KeyRepeatEvent ? 30 : 10) * 1000;
          _update(
            () => _drag =
                ((_drag ?? _position.inMilliseconds.toDouble()) +
                        (direction == TraversalDirection.left ? -step : step))
                    .clamp(
                      0.0,
                      _backend.value.duration.inMilliseconds.toDouble(),
                    ),
          );
        }
      } else if (_drag == null) {
        FocusManager.instance.primaryFocus?.focusInDirection(direction);
      }
      return KeyEventResult.handled;
    }
    // Child TvAction consumes confirmation. If the player itself owns focus,
    // the first confirmation moves to the primary action without toggling it.
    if (event is! KeyRepeatEvent && _panel == PlayerPanel.none) {
      _tvFocus['play']!.requestFocus();
    }
    return KeyEventResult.handled;
  }

  void _tvOpenPanel(PlayerPanel panel, String control) {
    _tvPanelReturn = _tvFocus[control];
    _openPanel(panel);
  }

  Widget _tvControl(
    String id,
    String label,
    IconData icon,
    VoidCallback? action, {
    bool autofocus = false,
  }) => TvAction(
    key: ValueKey('tv-player-$id'),
    focusNode: _tvFocus[id],
    autofocus: autofocus,
    onPressed: action,
    label: label,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: AppSemanticColors.playerForeground),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            color: AppSemanticColors.playerForeground,
          ),
        ),
      ],
    ),
  );

  Widget _tvBody() => ValueListenableBuilder<PlayerSnapshot>(
    valueListenable: _backend,
    builder: (context, value, _) => Stack(
      fit: StackFit.expand,
      children: [
        _videoLayer(),
        ..._statusLayers(),
        if (_controlsVisible) ...[
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x90000000),
                      Color(0x00000000),
                      Color(0xF0000000),
                    ],
                    stops: [0, .4, 1],
                  ),
                ),
              ),
            ),
          ),
          ExcludeFocus(
            excluding: _panel != PlayerPanel.none,
            child: FocusTraversalGroup(
              child: SafeArea(
                minimum: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _tvControl(
                          'back',
                          MaterialLocalizations.of(context).backButtonTooltip,
                          AppIcons.back,
                          () => unawaited(_exitPlayback()),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Text(
                            _displayTitle ?? _name ?? l.playerEmpty,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              color: AppSemanticColors.playerForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    TvAction(
                      key: const ValueKey('tv-player-seek'),
                      focusNode: _tvFocus['seek'],
                      label: l.playbackPosition,
                      onPressed: !_seekable
                          ? null
                          : () {
                              if (_drag != null) {
                                final target = _drag!;
                                _update(() => _drag = null);
                                _seekTo(Duration(milliseconds: target.round()));
                              }
                              _scheduleHide();
                            },
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                formatClock(
                                  Duration(
                                    milliseconds: _shownPosition(value).round(),
                                  ),
                                  value.duration,
                                ),
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: AppSemanticColors.playerForeground,
                                ),
                              ),
                              Text(
                                formatTime(value.duration),
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: AppSemanticColors.playerForeground,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            minHeight: 6,
                            value: value.duration.inMilliseconds <= 0
                                ? 0
                                : _shownPosition(value) /
                                      value.duration.inMilliseconds,
                            color: PlayerStyle.accent(context),
                            backgroundColor: Colors.white24,
                          ),
                          if (_drag != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              l.tvSeekHint,
                              style: const TextStyle(
                                fontSize: 18,
                                color: AppSemanticColors.playerForeground,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 14,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _tvControl(
                          'rewind',
                          '−10 s',
                          AppIcons.rewindOsd,
                          _seekable
                              ? () {
                                  _jump(const Duration(seconds: -10));
                                  _scheduleHide();
                                }
                              : null,
                        ),
                        _tvControl(
                          'play',
                          value.status == PlaybackStatus.playing
                              ? l.pause
                              : l.play,
                          value.status == PlaybackStatus.playing
                              ? AppIcons.pause
                              : AppIcons.play,
                          _enabled
                              ? () {
                                  _togglePlayback();
                                  _scheduleHide();
                                }
                              : null,
                          autofocus: widget.active,
                        ),
                        _tvControl(
                          'forward',
                          '+10 s',
                          AppIcons.forwardOsd,
                          _seekable
                              ? () {
                                  _jump(const Duration(seconds: 10));
                                  _scheduleHide();
                                }
                              : null,
                        ),
                        _tvControl(
                          'audio',
                          l.audioTrack,
                          AppIcons.audio,
                          _enabled
                              ? () => _tvOpenPanel(PlayerPanel.audio, 'audio')
                              : null,
                        ),
                        _tvControl(
                          'subtitles',
                          l.subtitleTrack,
                          AppIcons.captions,
                          _enabled
                              ? () => _tvOpenPanel(
                                  PlayerPanel.subtitles,
                                  'subtitles',
                                )
                              : null,
                        ),
                        _tvControl(
                          'speed',
                          formatSpeed(_speed),
                          AppIcons.speed,
                          _enabled
                              ? () => _tvOpenPanel(PlayerPanel.speed, 'speed')
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (_panel != PlayerPanel.none) _tvPanel(),
      ],
    ),
  );

  Widget _tvPanel() {
    final audio = _panel == PlayerPanel.audio;
    final subtitles = _panel == PlayerPanel.subtitles;
    Widget option(
      String id,
      String label,
      bool selected,
      VoidCallback action, {
      bool autofocus = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TvAction(
        key: ValueKey('tv-option-$id'),
        autofocus: autofocus,
        selected: selected,
        onPressed: action,
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 22))),
            if (selected) const Icon(Icons.check),
          ],
        ),
      ),
    );
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: SizedBox(
        width: math.min(440, MediaQuery.sizeOf(context).width),
        child: ColoredBox(
          color: AppTheme.dark.colorScheme.background,
          child: FocusScope(
            key: ValueKey('tv-panel-scope-${_panel.name}'),
            autofocus: true,
            node: _tvPanelScope,
            child: ListView(
              key: ValueKey('tv-panel-${_panel.name}'),
              padding: const EdgeInsets.all(32),
              children: [
                TvAction(
                  autofocus: true,
                  onPressed: _closePanel,
                  child: Row(
                    children: [
                      const Icon(AppIcons.close),
                      const SizedBox(width: 12),
                      Text(l.close),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  audio
                      ? l.audioTrack
                      : subtitles
                      ? l.subtitleTrack
                      : l.playbackSpeed,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(height: 24),
                if (audio) ...[
                  if (_audioState.tracks.isEmpty) Text(l.noAudioTracks),
                  for (final track in _audioState.tracks)
                    option(
                      'audio-${track.id}',
                      _audioName(track),
                      _audioState.current == track.id,
                      () => unawaited(_selectAudio(track.id)),
                    ),
                ] else if (subtitles) ...[
                  option(
                    'off',
                    l.subtitleOff,
                    _subtitleState.isOff,
                    () => unawaited(_subtitleOff()),
                  ),
                  for (final track in _subtitleState.options)
                    option(
                      'subtitle-${track.key}',
                      _subtitleName(track),
                      _subtitleState.isSelected(track),
                      () => unawaited(_chooseSubtitle(track)),
                    ),
                ] else ...[
                  for (final speed in speedPresets)
                    option(
                      'speed-$speed',
                      formatSpeed(speed),
                      speed == _speed,
                      () => unawaited(_setSpeed(speed)),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
