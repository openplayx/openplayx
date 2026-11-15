import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

/// A resolved key press: the action plus, for quick bookmarks, the slot.
@immutable
class PlayerKeyCommand {
  const PlayerKeyCommand(this.action, {this.bookmarkSlot, this.setBookmark});
  final PlayerAction? action;

  /// 0–9 for F1–F10 (jump) or Mod+F1–F10 (set).
  final int? bookmarkSlot;
  final bool? setBookmark;
}

bool get isApplePlatform =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

const _functionKeys = [
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.f2,
  LogicalKeyboardKey.f3,
  LogicalKeyboardKey.f4,
  LogicalKeyboardKey.f5,
  LogicalKeyboardKey.f6,
  LogicalKeyboardKey.f7,
  LogicalKeyboardKey.f8,
  LogicalKeyboardKey.f9,
  LogicalKeyboardKey.f10,
];

/// Maps one key press to a player command, or null when the key is not a
/// player shortcut. [primary] is Control (Windows/Linux) or Command (Apple);
/// the other of the two is never part of a player shortcut.
PlayerKeyCommand? resolvePlayerKey(
  LogicalKeyboardKey key, {
  required bool shift,
  required bool alt,
  required bool primary,
  required bool otherModifier,
}) {
  if (otherModifier) return null;
  final slot = _functionKeys.indexOf(key);
  if (slot >= 0 && !shift && !alt) {
    return PlayerKeyCommand(null, bookmarkSlot: slot, setBookmark: primary);
  }
  PlayerAction? action;
  final plain = !shift && !alt && !primary;
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
  return action == null ? null : PlayerKeyCommand(action);
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
