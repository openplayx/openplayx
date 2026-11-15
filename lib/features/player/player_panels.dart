part of 'player_page.dart';

/// Panel contents shared by the desktop popovers/side panel and the mobile
/// sheets (design §5): the same functions, different containers.
extension _PlayerPanels on PlayerPageState {
  Widget _speedContent() {
    final accent = PlayerStyle.accent(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerSectionLabel(
          l.playbackSpeed,
          trailing: Text(
            formatSpeed(_speed),
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w600,
              fontFeatures: PlayerStyle.tabular,
            ),
          ),
        ),
        PlayerChoiceWrap<double>(
          options: speedPresets,
          selected: _speed,
          label: formatSpeed,
          onSelected: (speed) => unawaited(_setSpeed(speed)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: Row(
            children: [
              PlayerIconButton(
                tooltip: l.plSlower,
                icon: AppIcons.minus,
                size: 32,
                iconSize: 16,
                onPressed: _enabled
                    ? () => _setSpeed(_speed - fineSpeedStep)
                    : null,
              ),
              Expanded(
                child: ShadSlider(
                  key: ValueKey('speed-slider-$_speed'),
                  initialValue: _speed,
                  min: minSpeed,
                  max: maxSpeed,
                  divisions: ((maxSpeed - minSpeed) / fineSpeedStep).round(),
                  onChangeEnd: (value) => unawaited(_setSpeed(value)),
                ),
              ),
              PlayerIconButton(
                tooltip: l.plFaster,
                icon: AppIcons.plus,
                size: 32,
                iconSize: 16,
                onPressed: _enabled
                    ? () => _setSpeed(_speed + fineSpeedStep)
                    : null,
              ),
            ],
          ),
        ),
        PlayerMenuRow(
          label: l.plNormalSpeed,
          value: '1×',
          enabled: _enabled && _speed != 1,
          onTap: () => _setSpeed(1),
        ),
      ],
    );
  }

  Widget _trackList({required bool audio}) {
    final children = <Widget>[];
    if (audio) {
      if (_audioTracks.isEmpty) {
        children.add(PlayerMenuRow(label: l.noAudioTracks, enabled: false));
      }
      for (final track in _audioTracks) {
        children.add(
          PlayerMenuRow(
            label: _audioName(track),
            subtitle: track.language,
            height: _mobileDisplay ? 48 : 36,
            selected: _selectedAudioTrack == track.id,
            onTap: () => _selectAudio(track.id),
          ),
        );
      }
    } else {
      children.add(
        PlayerMenuRow(
          label: l.subtitleOff,
          height: _mobileDisplay ? 48 : 36,
          selected: _selectedSubtitleTrack == -1,
          onTap: () => _selectSubtitle(-1),
        ),
      );
      if (_subtitleTracks.isEmpty && _recognized.isEmpty) {
        children.add(PlayerMenuRow(label: l.noSubtitleTracks, enabled: false));
      }
      for (final track in _subtitleTracks) {
        children.add(
          PlayerMenuRow(
            label: _subtitleName(track),
            subtitle: track.language,
            height: _mobileDisplay ? 48 : 36,
            selected:
                _selectedRecognized == null &&
                _selectedSubtitleTrack == track.id,
            onTap: () => _selectSubtitle(track.id),
          ),
        );
      }
      if (_recognized.isNotEmpty) {
        children.add(
          PlayerSectionLabel(
            l.recognizedSubtitles,
            key: const ValueKey('recognized-subtitles'),
          ),
        );
      }
      for (final s in _recognized) {
        children.add(
          PlayerMenuRow(
            key: ValueKey('recognized-${s.bindingId}'),
            label:
                '${l.recognizedSubtitleBadge} · ${l.recognizedSubtitleTitle(s.created.toLocal().toString().substring(0, 16))}',
            subtitle: _recognizedDetail(s),
            height: _mobileDisplay ? 48 : 36,
            selected: _selectedRecognized == s.bindingId,
            onTap: () async {
              if (_enabled) await _selectRecognized(s);
            },
          ),
        );
      }
      // Phones offer this in the column header (design M-5).
      if (_backend.supportsExternalSubtitles && !_mobileDisplay) {
        children.add(
          PlayerMenuRow(
            icon: AppIcons.addSubtitle,
            label: l.plLoadSubtitle,
            onTap: _addSubtitleFile,
          ),
        );
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _tracksContent() {
    final audio = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [PlayerSectionLabel(l.audioTrack), _trackList(audio: true)],
    );
    final subtitles = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerSectionLabel(
          l.subtitleTrack,
          trailing: _mobileDisplay && _backend.supportsExternalSubtitles
              ? GestureDetector(
                  key: const Key('add-subtitle-header'),
                  onTap: _addSubtitleFile,
                  child: Text(
                    l.plExternalSubtitleShort,
                    style: TextStyle(
                      color: PlayerStyle.accent(context),
                      fontSize: 12,
                    ),
                  ),
                )
              : null,
        ),
        _trackList(audio: false),
      ],
    );
    Widget delayCard(IconData icon, String label, Duration value) => Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _openSync,
          child: Container(
            height: _mobileDisplay ? 46 : 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0x0FFFFFFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: PlayerStyle.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
                Text(
                  formatDelay(value),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFeatures: PlayerStyle.tabular,
                    color: value == Duration.zero
                        ? PlayerStyle.fg
                        : PlayerStyle.accent(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final delays = _backend.supportsDelays
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                delayCard(AppIcons.audio, l.plAudioDelay, _audioDelay),
                const SizedBox(width: 8),
                delayCard(AppIcons.captions, l.plSubtitleDelay, _subtitleDelay),
              ],
            ),
          )
        : null;
    return LayoutBuilder(
      builder: (context, box) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (box.maxWidth >= 420)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: audio),
                const SizedBox(width: 12),
                Expanded(child: subtitles),
              ],
            )
          else ...[
            audio,
            subtitles,
          ],
          if (delays != null) ...[
            const Divider(color: PlayerStyle.glassStroke, height: 12),
            delays,
          ],
        ],
      ),
    );
  }

  Widget _delayRow(
    String label,
    Duration value,
    Future<void> Function(Duration) apply,
    String key,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5))),
        PlayerIconButton(
          key: Key('$key-minus'),
          tooltip: '$label −${_prefs.delayStep.inMilliseconds} ms',
          icon: AppIcons.minus,
          size: 36,
          iconSize: 16,
          onPressed: _enabled ? () => apply(value - _prefs.delayStep) : null,
        ),
        SizedBox(
          width: 72,
          child: Text(
            formatDelay(value),
            key: Key('$key-value'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: PlayerStyle.tabular,
              color: value == Duration.zero
                  ? PlayerStyle.fg
                  : PlayerStyle.accent(context),
            ),
          ),
        ),
        PlayerIconButton(
          key: Key('$key-plus'),
          tooltip: '$label +${_prefs.delayStep.inMilliseconds} ms',
          icon: AppIcons.plus,
          size: 36,
          iconSize: 16,
          onPressed: _enabled ? () => apply(value + _prefs.delayStep) : null,
        ),
        TextButton(
          onPressed: _enabled && value != Duration.zero
              ? () => apply(Duration.zero)
              : null,
          child: Text(l.plReset),
        ),
      ],
    ),
  );

  Widget _syncContent() {
    if (!_backend.supportsDelays) {
      return PlayerMenuRow(label: l.plUnsupported, enabled: false);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerSectionLabel(l.plSync),
        _delayRow(l.plAudioDelay, _audioDelay, _setAudioDelay, 'audio-delay'),
        _delayRow(
          l.plSubtitleDelay,
          _subtitleDelay,
          _setSubtitleDelay,
          'subtitle-delay',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          child: Text(
            l.plDelayHint,
            style: const TextStyle(color: PlayerStyle.muted, fontSize: 11.5),
          ),
        ),
      ],
    );
  }

  Widget _frameContent() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PlayerSectionLabel(
        l.plFitMode,
        trailing: _frame.isDefault
            ? null
            : GestureDetector(
                onTap: () => _update(() => _frame = const VideoFrameSettings()),
                child: Text(
                  l.plReset,
                  style: TextStyle(
                    color: PlayerStyle.accent(context),
                    fontSize: 12,
                  ),
                ),
              ),
      ),
      PlayerChoiceWrap<VideoFitMode>(
        options: VideoFitMode.values,
        selected: _frame.mode,
        label: _fitLabel,
        onSelected: (mode) => _setFrame(_frame.copyWith(mode: mode)),
      ),
      PlayerSectionLabel(l.plAspectRatio),
      PlayerChoiceWrap<int>(
        options: [for (var i = 0; i < videoAspectRatios.length; i++) i],
        selected: _frame.aspectIndex,
        label: (i) => videoAspectLabels[i] ?? l.plAspectDefault,
        onSelected: (i) => _setFrame(_frame.copyWith(aspectIndex: i)),
      ),
      PlayerSectionLabel(l.plZoom),
      PlayerChoiceWrap<double>(
        options: videoZoomSteps,
        selected: _frame.zoom,
        label: _zoomLabel,
        onSelected: (zoom) => _setFrame(_frame.copyWith(zoom: zoom)),
      ),
      PlayerSectionLabel(_displayLabel),
      if (_mobileDisplay)
        PlayerMenuRow(
          icon: AppIcons.screenOrientation,
          label: _displayLabel,
          value: switch (_screenOrientation) {
            PlayerScreenOrientation.system => l.orientationSystem,
            PlayerScreenOrientation.portrait => l.orientationPortrait,
            PlayerScreenOrientation.landscape => l.orientationLandscape,
          },
          chevron: true,
          onTap: _showDisplayOptions,
        )
      else
        PlayerChoiceWrap<int>(
          key: const Key('rotation-choices'),
          options: const [0, 1, 2, 3],
          selected: _videoQuarterTurns,
          label: (turns) => turns == 0 ? l.rotationOriginal : '${turns * 90}°',
          onSelected: (turns) => _update(() => _videoQuarterTurns = turns),
        ),
    ],
  );

  Widget _infoContent() {
    final info = _mediaInfo;
    final stats = _stats;
    String kbps(double value) => value <= 0
        ? '--'
        : value >= 1000
        ? '${(value / 1000).toStringAsFixed(2)} Mb/s'
        : '${value.toStringAsFixed(0)} kb/s';
    final value = _backend.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerSectionLabel(l.plMediaInfo),
        PlayerMenuRow(label: l.plInfoTitle, value: info?.title ?? _title),
        if (value.videoSize != null)
          PlayerMenuRow(
            label: l.plInfoResolution,
            value:
                '${value.videoSize!.width.round()} × ${value.videoSize!.height.round()}',
          ),
        PlayerMenuRow(
          label: l.plInfoDuration,
          value: value.duration > Duration.zero
              ? formatTime(value.duration)
              : '--:--',
        ),
        for (final track in info?.tracks ?? const <PlayerTrackInfo>[])
          PlayerMenuRow(
            label: switch (track.type) {
              'video' => l.plTrackVideo,
              'audio' => l.plTrackAudio,
              'subtitle' || 'text' => l.plTrackSubtitle,
              _ => track.type,
            },
            value: [
              if (track.codec != null) track.codec!,
              if (track.width != null && track.height != null)
                '${track.width}×${track.height}',
              if (track.channels != null) '${track.channels} ch',
              if (track.sampleRate != null) '${track.sampleRate} Hz',
              if (track.language != null) track.language!,
            ].join(' · '),
          ),
        PlayerSectionLabel(l.plStatistics),
        PlayerMenuRow(
          label: l.plStatsRead,
          value: value.readSpeedMBps == null
              ? '-- MB/s'
              : '${value.readSpeedMBps!.toStringAsFixed(2)} MB/s',
        ),
        PlayerMenuRow(
          label: l.plStatsInput,
          value: kbps(stats?.inputKbps ?? 0),
        ),
        PlayerMenuRow(
          label: l.plStatsDemux,
          value: kbps(stats?.demuxKbps ?? 0),
        ),
        PlayerMenuRow(
          label: l.plStatsFrames,
          value: stats == null
              ? '--'
              : '${stats.displayedPictures} / ${stats.lostPictures}',
        ),
        PlayerMenuRow(
          label: l.plStatsAudio,
          value: stats == null
              ? '--'
              : '${stats.playedAudioBuffers} / ${stats.lostAudioBuffers}',
        ),
        if (_backend.supportsMediaInfo)
          PlayerMenuRow(
            icon: AppIcons.stats,
            label: l.plStatsOverlay,
            selected: _statsOverlay,
            onTap: _toggleStatsOverlay,
          ),
      ],
    );
  }

  /// Floating "stats for nerds" card (design §5.7).
  Widget _statsCard() {
    final value = _backend.value;
    final stats = _stats;
    String kbps(double v) => v <= 0 ? '--' : '${v.toStringAsFixed(0)} kb/s';
    final rows = <(String, String)>[
      (
        l.plInfoResolution,
        value.videoSize == null
            ? '--'
            : '${value.videoSize!.width.round()}×${value.videoSize!.height.round()}',
      ),
      (
        l.plStatsRead,
        value.readSpeedMBps == null
            ? '-- MB/s'
            : '${value.readSpeedMBps!.toStringAsFixed(2)} MB/s',
      ),
      (l.plStatsInput, kbps(stats?.inputKbps ?? 0)),
      (l.plStatsDemux, kbps(stats?.demuxKbps ?? 0)),
      (
        l.plStatsFrames,
        stats == null
            ? '--'
            : '${stats.displayedPictures} / ${stats.lostPictures}',
      ),
      (
        l.plStatsAudio,
        stats == null
            ? '--'
            : '${stats.playedAudioBuffers} / ${stats.lostAudioBuffers}',
      ),
    ];
    return PlayerGlass(
      key: const Key('stats-overlay'),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.plStatistics,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 24),
              PlayerIconButton(
                tooltip: l.close,
                icon: AppIcons.close,
                size: 28,
                iconSize: 14,
                onPressed: _toggleStatsOverlay,
              ),
            ],
          ),
          for (final (label, text) in rows)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Text(
                '$label  $text',
                style: const TextStyle(
                  fontSize: 12,
                  fontFeatures: PlayerStyle.tabular,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sleepContent() {
    String label(int minutes) =>
        minutes < 0 ? l.plSleepEndOfItem : l.plSleepMinutes(minutes);
    final active = _sleepAt != null || _sleepAtEnd;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerSectionLabel(
          l.plSleepTimer,
          trailing: _sleepAt == null
              ? null
              : Text(
                  formatTime(_sleepAt!.difference(DateTime.now())),
                  style: TextStyle(
                    color: PlayerStyle.accent(context),
                    fontFeatures: PlayerStyle.tabular,
                  ),
                ),
        ),
        PlayerMenuRow(
          label: l.plSleepOff,
          selected: !active,
          onTap: () {
            _setSleep(null);
            _closePanel();
          },
        ),
        for (final minutes in sleepTimerChoices)
          PlayerMenuRow(
            label: label(minutes),
            height: _mobileDisplay ? 44 : 34,
            selected: minutes < 0 && _sleepAtEnd,
            onTap: () {
              _setSleep(minutes);
              _closePanel();
              _flash(AppIcons.sleep, label(minutes));
            },
          ),
      ],
    );
  }

  Widget _bookmarksContent() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PlayerSectionLabel(l.plBookmarks),
      PlayerMenuRow(
        icon: AppIcons.plus,
        label: l.plAddBookmark,
        value: formatTime(_backend.value.position),
        enabled: _seekable,
        onTap: _addBookmark,
      ),
      if (_bookmarks.isEmpty)
        PlayerMenuRow(label: l.plNoBookmarks, enabled: false),
      for (final bookmark in _bookmarks)
        Row(
          children: [
            Expanded(
              child: PlayerMenuRow(
                icon: AppIcons.bookmark,
                label: bookmark.name ?? formatTime(bookmark.position),
                onTap: () {
                  _seekTo(bookmark.position);
                  _closePanel();
                },
              ),
            ),
            PlayerIconButton(
              tooltip: l.plDeleteBookmark,
              icon: AppIcons.delete,
              size: 32,
              iconSize: 15,
              onPressed: () => _update(() => _bookmarks.remove(bookmark)),
            ),
          ],
        ),
    ],
  );

  Widget _helpContent() {
    final groups = <(String, List<PlayerAction>)>[
      (
        l.plMenuPlayback,
        [
          PlayerAction.togglePlay,
          PlayerAction.stop,
          PlayerAction.jumpBackShort,
          PlayerAction.jumpForwardShort,
          PlayerAction.jumpForwardExtraShort,
          PlayerAction.jumpForwardMedium,
          PlayerAction.jumpForwardLong,
          PlayerAction.faster,
          PlayerAction.slower,
          PlayerAction.normalSpeed,
          PlayerAction.jumpToTime,
          PlayerAction.showPosition,
          PlayerAction.cycleRepeat,
        ],
      ),
      (
        l.plMenuAudio,
        [
          PlayerAction.volumeUp,
          PlayerAction.volumeDown,
          PlayerAction.mute,
          PlayerAction.nextAudioTrack,
          PlayerAction.audioDelayUp,
          PlayerAction.audioDelayDown,
        ],
      ),
      (
        l.plMenuSubtitle,
        [
          PlayerAction.nextSubtitle,
          PlayerAction.toggleSubtitles,
          PlayerAction.subtitleDelayUp,
          PlayerAction.subtitleDelayDown,
        ],
      ),
      (
        l.plMenuVideo,
        [
          PlayerAction.toggleFullscreen,
          PlayerAction.cycleAspectRatio,
          PlayerAction.cycleFitMode,
          PlayerAction.cycleZoom,
          PlayerAction.snapshot,
          PlayerAction.toggleControls,
        ],
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerSectionLabel(l.plShortcuts),
        Wrap(
          children: [
            for (final (title, actions) in groups)
              SizedBox(
                width: 270,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PlayerSectionLabel(title),
                    for (final action in actions)
                      PlayerMenuRow(
                        height: 28,
                        label: _actionLabel(action),
                        value: playerShortcutLabel(action),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _actionLabel(PlayerAction action) => switch (action) {
    PlayerAction.togglePlay => '${l.play} / ${l.pause}',
    PlayerAction.stop => l.plStop,
    PlayerAction.toggleFullscreen => l.plFullscreen,
    PlayerAction.jumpBackShort => l.rewind,
    PlayerAction.jumpForwardShort => l.forward,
    PlayerAction.jumpBackExtraShort ||
    PlayerAction.jumpForwardExtraShort => l.plJumpExtraShort,
    PlayerAction.jumpBackMedium ||
    PlayerAction.jumpForwardMedium => l.plJumpForwardMedium,
    PlayerAction.jumpBackLong || PlayerAction.jumpForwardLong => l.plJumpLong,
    PlayerAction.faster || PlayerAction.fasterFine => l.plFaster,
    PlayerAction.slower || PlayerAction.slowerFine => l.plSlower,
    PlayerAction.normalSpeed => l.plNormalSpeed,
    PlayerAction.showPosition => l.plShowPosition,
    PlayerAction.jumpToTime => l.plJumpToTime,
    PlayerAction.volumeUp => '${l.volume} +',
    PlayerAction.volumeDown => '${l.volume} −',
    PlayerAction.mute => l.plMute,
    PlayerAction.nextAudioTrack => l.plNextAudioTrack,
    PlayerAction.nextSubtitle ||
    PlayerAction.previousSubtitle => l.plNextSubtitle,
    PlayerAction.toggleSubtitles => l.plToggleSubtitles,
    PlayerAction.subtitleDelayUp => '${l.plSubtitleDelay} +',
    PlayerAction.subtitleDelayDown => '${l.plSubtitleDelay} −',
    PlayerAction.audioDelayUp => '${l.plAudioDelay} +',
    PlayerAction.audioDelayDown => '${l.plAudioDelay} −',
    PlayerAction.cycleAspectRatio => l.plAspectRatio,
    PlayerAction.cycleZoom || PlayerAction.cycleZoomReverse => l.plZoom,
    PlayerAction.cycleFitMode => l.plFitMode,
    PlayerAction.toggleControls => l.plToggleControls,
    PlayerAction.snapshot => l.plSnapshot,
    PlayerAction.cycleRepeat => l.plRepeatMode,
    PlayerAction.openFile => l.openFile,
    PlayerAction.shortcutHelp => l.plShortcuts,
  };
}
