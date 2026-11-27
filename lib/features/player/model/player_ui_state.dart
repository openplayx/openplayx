/// Panels and sheets the player shows over the video (design §3.5, §4.4).
enum PlayerPanel {
  none,
  tracks,

  /// Phones: audio tracks and subtitles open separately.
  audio,
  subtitles,
  alignment,
  speed,
  settings,
  more,
  sleep,
  frame,
  sync,
  info,
  help,
}

/// Desktop "设置与效果" side panel tabs.
enum SettingsTab { picture, sync, info }
