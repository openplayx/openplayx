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

/// Persistent speed presets (design §5.2) and the fine step.
const speedPresets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0, 4.0];
const minSpeed = 0.25, maxSpeed = 4.0, fineSpeedStep = 0.05;

double nextSpeedPreset(double speed, {required bool faster}) {
  if (faster) {
    return speedPresets.firstWhere(
      (preset) => preset > speed + 1e-6,
      orElse: () => maxSpeed,
    );
  }
  return speedPresets.lastWhere(
    (preset) => preset < speed - 1e-6,
    orElse: () => minSpeed,
  );
}

double clampSpeed(double speed) =>
    (speed.clamp(minSpeed, maxSpeed) * 100).roundToDouble() / 100;

/// Temporary long-press speed (design MG10): 2×, or one above a persistent
/// speed of at least 2×, at most 8×.
double boostSpeed(double persistent) =>
    persistent >= 2 ? (persistent + 1).clamp(2, 8).toDouble() : 2;

/// Formats a speed without trailing zeros: 1×, 1.25×, 0.5×.
String formatSpeed(double speed) {
  var text = speed.toStringAsFixed(2);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  return '$text×';
}

enum AbPhase { off, aSet, looping }

/// A-B repeat (design §5.6): first press sets A, second sets B and starts
/// looping, third clears.
@immutable
class AbLoop {
  const AbLoop({this.a, this.b});
  final Duration? a, b;

  AbPhase get phase => a == null
      ? AbPhase.off
      : b == null
      ? AbPhase.aSet
      : AbPhase.looping;

  AbLoop advance(Duration position) => switch (phase) {
    AbPhase.off => AbLoop(a: position),
    AbPhase.aSet =>
      position > a!
          ? AbLoop(a: a, b: position)
          : position < a!
          ? AbLoop(a: position, b: a)
          : this,
    AbPhase.looping => const AbLoop(),
  };

  /// Where to jump for [position] while looping, if anywhere: back to A
  /// once B is reached.
  Duration? jumpFor(Duration position) =>
      phase == AbPhase.looping && position >= b! ? a : null;
}

/// A named point in the current media (design §5.6).
@immutable
class PlayerBookmark {
  const PlayerBookmark(this.position, {this.name});
  final Duration position;
  final String? name;
}

/// Sleep timer choices in minutes; -1 stops at the end of the current item.
const sleepTimerChoices = [15, 30, 45, 60, 90, -1];

/// Signed delay label: "+0.30 s", "-0.05 s", "0.00 s".
String formatDelay(Duration delay) {
  final seconds = delay.inMilliseconds / 1000;
  final sign = seconds > 0 ? '+' : '';
  return '$sign${seconds.toStringAsFixed(2)} s';
}
