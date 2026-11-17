import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../model/player_action.dart';

bool get isApplePlatform =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Maps one key press to a player command, or null when the key is not a
/// player shortcut. [primary] is Control (Windows/Linux) or Command (Apple);
/// the other of the two is never part of a player shortcut.
PlayerAction? resolvePlayerKey(
  LogicalKeyboardKey key, {
  required bool shift,
  required bool alt,
  required bool primary,
  required bool otherModifier,
}) {
  if (otherModifier) return null;
  PlayerAction? action;
  final plain = !shift && !alt && !primary;
  // TV remote and media keys (D-pad arrows are the arrow keys below).
  final remote = switch (key) {
    LogicalKeyboardKey.select ||
    LogicalKeyboardKey.mediaPlayPause => PlayerAction.togglePlay,
    LogicalKeyboardKey.mediaStop => PlayerAction.stop,
    LogicalKeyboardKey.mediaFastForward => PlayerAction.jumpForwardMedium,
    LogicalKeyboardKey.mediaRewind => PlayerAction.jumpBackMedium,
    LogicalKeyboardKey.closedCaptionToggle => PlayerAction.nextSubtitle,
    LogicalKeyboardKey.mediaAudioTrack => PlayerAction.nextAudioTrack,
    LogicalKeyboardKey.info => PlayerAction.showPosition,
    LogicalKeyboardKey.contextMenu => PlayerAction.toggleControls,
    _ => null,
  };
  if (remote != null) return plain ? remote : null;
  if (key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowRight) {
    final back = key == LogicalKeyboardKey.arrowLeft;
    if (shift && !alt && !primary) {
      action = back
          ? PlayerAction.jumpBackExtraShort
          : PlayerAction.jumpForwardExtraShort;
    } else if (plain || (alt && !shift && !primary)) {
      action = back
          ? PlayerAction.jumpBackShort
          : PlayerAction.jumpForwardShort;
    } else if (primary && !alt && !shift) {
      action = back
          ? PlayerAction.jumpBackMedium
          : PlayerAction.jumpForwardMedium;
    } else if (primary && alt && !shift) {
      action = back ? PlayerAction.jumpBackLong : PlayerAction.jumpForwardLong;
    }
  } else if (key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown) {
    if (!shift && !alt) {
      action = key == LogicalKeyboardKey.arrowUp
          ? PlayerAction.volumeUp
          : PlayerAction.volumeDown;
    }
  } else if (key == LogicalKeyboardKey.add ||
      key == LogicalKeyboardKey.numpadAdd) {
    if (!alt && !primary) action = PlayerAction.faster;
  } else if (key == LogicalKeyboardKey.equal) {
    if (!alt && !primary) {
      // "+" shares the key with "=" on most layouts.
      action = shift ? PlayerAction.faster : PlayerAction.normalSpeed;
    }
  } else if (key == LogicalKeyboardKey.minus ||
      key == LogicalKeyboardKey.numpadSubtract) {
    if (plain) action = PlayerAction.slower;
  } else if (key == LogicalKeyboardKey.bracketRight) {
    if (plain) action = PlayerAction.fasterFine;
  } else if (key == LogicalKeyboardKey.bracketLeft) {
    if (plain) action = PlayerAction.slowerFine;
  } else if (key == LogicalKeyboardKey.slash ||
      key == LogicalKeyboardKey.question) {
    if (shift || key == LogicalKeyboardKey.question) {
      action = PlayerAction.shortcutHelp;
    }
  } else if (key == LogicalKeyboardKey.space) {
    if (plain) action = PlayerAction.togglePlay;
  } else if (primary && !alt && !shift) {
    action = switch (key) {
      LogicalKeyboardKey.keyT => PlayerAction.jumpToTime,
      LogicalKeyboardKey.keyO => PlayerAction.openFile,
      _ => null,
    };
  } else if (shift && !alt && !primary) {
    action = switch (key) {
      LogicalKeyboardKey.keyV => PlayerAction.toggleSubtitles,
      LogicalKeyboardKey.keyZ => PlayerAction.cycleZoomReverse,
      LogicalKeyboardKey.keyS => PlayerAction.snapshot,
      _ => null,
    };
  } else if (alt && !shift && !primary) {
    if (key == LogicalKeyboardKey.keyV) action = PlayerAction.previousSubtitle;
  } else if (plain) {
    action = switch (key) {
      LogicalKeyboardKey.keyS => PlayerAction.stop,
      LogicalKeyboardKey.keyF => PlayerAction.toggleFullscreen,
      LogicalKeyboardKey.keyT => PlayerAction.showPosition,
      LogicalKeyboardKey.keyM => PlayerAction.mute,
      LogicalKeyboardKey.keyB => PlayerAction.nextAudioTrack,
      LogicalKeyboardKey.keyV => PlayerAction.nextSubtitle,
      LogicalKeyboardKey.keyH => PlayerAction.subtitleDelayUp,
      LogicalKeyboardKey.keyG => PlayerAction.subtitleDelayDown,
      LogicalKeyboardKey.keyK => PlayerAction.audioDelayUp,
      LogicalKeyboardKey.keyJ => PlayerAction.audioDelayDown,
      LogicalKeyboardKey.keyA => PlayerAction.cycleAspectRatio,
      LogicalKeyboardKey.keyZ => PlayerAction.cycleZoom,
      LogicalKeyboardKey.keyO => PlayerAction.cycleFitMode,
      LogicalKeyboardKey.keyI => PlayerAction.toggleControls,
      LogicalKeyboardKey.keyL => PlayerAction.cycleRepeat,
      _ => null,
    };
  }
  return action;
}

/// Display label of an action's default shortcut, e.g. "⇧S" or "Ctrl+T".
String? playerShortcutLabel(PlayerAction action, {bool? apple}) {
  final mac = apple ?? isApplePlatform;
  final mod = mac ? '⌘' : 'Ctrl+';
  final alt = mac ? '⌥' : 'Alt+';
  final shift = mac ? '⇧' : 'Shift+';
  return switch (action) {
    PlayerAction.togglePlay => 'Space',
    PlayerAction.stop => 'S',
    PlayerAction.toggleFullscreen => 'F',
    PlayerAction.jumpBackExtraShort => '$shift←',
    PlayerAction.jumpForwardExtraShort => '$shift→',
    PlayerAction.jumpBackShort => '←',
    PlayerAction.jumpForwardShort => '→',
    PlayerAction.jumpBackMedium => '$mod←',
    PlayerAction.jumpForwardMedium => '$mod→',
    PlayerAction.jumpBackLong => '$mod$alt←',
    PlayerAction.jumpForwardLong => '$mod$alt→',
    PlayerAction.faster => '+',
    PlayerAction.slower => '−',
    PlayerAction.fasterFine => ']',
    PlayerAction.slowerFine => '[',
    PlayerAction.normalSpeed => '=',
    PlayerAction.showPosition => 'T',
    PlayerAction.jumpToTime => '${mod}T',
    PlayerAction.volumeUp => '↑',
    PlayerAction.volumeDown => '↓',
    PlayerAction.mute => 'M',
    PlayerAction.nextAudioTrack => 'B',
    PlayerAction.nextSubtitle => 'V',
    PlayerAction.previousSubtitle => '${alt}V',
    PlayerAction.toggleSubtitles => '${shift}V',
    PlayerAction.subtitleDelayUp => 'H',
    PlayerAction.subtitleDelayDown => 'G',
    PlayerAction.audioDelayUp => 'K',
    PlayerAction.audioDelayDown => 'J',
    PlayerAction.cycleAspectRatio => 'A',
    PlayerAction.cycleZoom => 'Z',
    PlayerAction.cycleZoomReverse => '${shift}Z',
    PlayerAction.cycleFitMode => 'O',
    PlayerAction.toggleControls => 'I',
    PlayerAction.snapshot => '${shift}S',
    PlayerAction.cycleRepeat => 'L',
    PlayerAction.openFile => '${mod}O',
    PlayerAction.shortcutHelp => '?',
  };
}
