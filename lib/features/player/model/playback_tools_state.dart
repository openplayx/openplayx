import 'package:flutter/foundation.dart';

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

/// Sleep timer choices in minutes; -1 stops at the end of the current item.
const sleepTimerChoices = [15, 30, 45, 60, 90, -1];

/// Signed delay label: "+0.30 s", "-0.05 s", "0.00 s".
String formatDelay(Duration delay) {
  final seconds = delay.inMilliseconds / 1000;
  final sign = seconds > 0 ? '+' : '';
  return '$sign${seconds.toStringAsFixed(2)} s';
}

/// Speed, A-B loop, sleep timer and repeat of the player.
@immutable
class PlaybackToolsState {
  const PlaybackToolsState({
    this.speed = 1,
    this.boosting = false,
    this.ab = const AbLoop(),
    this.sleepAt,
    this.sleepAtEnd = false,
    this.repeatOne = false,
  });

  /// Persistent playback speed.
  final double speed;

  /// A long press temporarily plays at [boostSpeed] of [speed].
  final bool boosting;
  final AbLoop ab;

  /// When the sleep timer pauses playback, if set.
  final DateTime? sleepAt;

  /// Pause at the end of the current item instead.
  final bool sleepAtEnd;
  final bool repeatOne;

  bool get sleeping => sleepAt != null || sleepAtEnd;

  PlaybackToolsState copyWith({
    double? speed,
    bool? boosting,
    AbLoop? ab,
    DateTime? Function()? sleepAt,
    bool? sleepAtEnd,
    bool? repeatOne,
  }) => PlaybackToolsState(
    speed: speed ?? this.speed,
    boosting: boosting ?? this.boosting,
    ab: ab ?? this.ab,
    sleepAt: sleepAt == null ? this.sleepAt : sleepAt(),
    sleepAtEnd: sleepAtEnd ?? this.sleepAtEnd,
    repeatOne: repeatOne ?? this.repeatOne,
  );
}
