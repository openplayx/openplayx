/// Player commands reachable from the keyboard, menus and gestures.
///
/// Key bindings follow VLC's Qt defaults (design: player_page_design.md §6);
/// the primary modifier is Control on Windows/Linux and Command on macOS.
enum PlayerAction {
  togglePlay,
  stop,
  toggleFullscreen,
  jumpBackExtraShort,
  jumpForwardExtraShort,
  jumpBackShort,
  jumpForwardShort,
  jumpBackMedium,
  jumpForwardMedium,
  jumpBackLong,
  jumpForwardLong,
  faster,
  slower,
  fasterFine,
  slowerFine,
  normalSpeed,
  showPosition,
  jumpToTime,
  volumeUp,
  volumeDown,
  mute,
  nextAudioTrack,
  nextSubtitle,
  previousSubtitle,
  toggleSubtitles,
  subtitleDelayUp,
  subtitleDelayDown,
  audioDelayUp,
  audioDelayDown,
  cycleAspectRatio,
  cycleZoom,
  cycleZoomReverse,
  cycleFitMode,
  toggleControls,
  snapshot,
  cycleRepeat,
  openFile,
  shortcutHelp,
}

/// Keys whose repeat events must not toggle a state back and forth.
bool isTogglePlayerAction(PlayerAction action) => switch (action) {
  PlayerAction.togglePlay ||
  PlayerAction.stop ||
  PlayerAction.toggleFullscreen ||
  PlayerAction.mute ||
  PlayerAction.toggleSubtitles ||
  PlayerAction.toggleControls ||
  PlayerAction.snapshot ||
  PlayerAction.cycleRepeat ||
  PlayerAction.openFile ||
  PlayerAction.jumpToTime ||
  PlayerAction.shortcutHelp ||
  PlayerAction.cycleAspectRatio ||
  PlayerAction.cycleFitMode ||
  PlayerAction.cycleZoom ||
  PlayerAction.cycleZoomReverse ||
  PlayerAction.nextAudioTrack ||
  PlayerAction.nextSubtitle ||
  PlayerAction.previousSubtitle => true,
  _ => false,
};
