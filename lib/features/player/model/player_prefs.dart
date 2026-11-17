import 'package:flutter/foundation.dart';

/// Defaults from the playback design (§5): VLC's jump lengths and the
/// control-hiding delays. Kept in one place so a settings page can later
/// persist and edit them.
@immutable
class PlayerPrefs {
  const PlayerPrefs({
    this.extraShortJump = const Duration(seconds: 3),
    this.shortJump = const Duration(seconds: 10),
    this.mediumJump = const Duration(minutes: 1),
    this.longJump = const Duration(minutes: 5),
    this.doubleTapJump = const Duration(seconds: 10),
    this.desktopHideDelay = const Duration(seconds: 2),
    this.mobileHideDelay = const Duration(seconds: 4),
    this.clickToPause = true,
    this.volumeStep = 5,
    this.delayStep = const Duration(milliseconds: 50),
  });
  final Duration extraShortJump, shortJump, mediumJump, longJump;
  final Duration doubleTapJump, desktopHideDelay, mobileHideDelay;

  /// Desktop: a single click on the video toggles playback (VLC 3 does not).
  final bool clickToPause;
  final int volumeStep;
  final Duration delayStep;
}
