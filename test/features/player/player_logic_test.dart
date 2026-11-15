import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/features/player/player_extras.dart';
import 'package:openplayx/features/player/player_keymap.dart';
import 'package:openplayx/features/player/player_page.dart';
import 'package:openplayx/features/player/video_frame.dart';

PlayerAction? key(
  LogicalKeyboardKey key, {
  bool shift = false,
  bool alt = false,
  bool primary = false,
  bool other = false,
}) => resolvePlayerKey(
  key,
  shift: shift,
  alt: alt,
  primary: primary,
  otherModifier: other,
)?.action;

void main() {
  group('keymap follows VLC Qt defaults', () {
    test('four jump lengths by modifier', () {
      const left = LogicalKeyboardKey.arrowLeft;
      const right = LogicalKeyboardKey.arrowRight;
      expect(key(left, shift: true), PlayerAction.jumpBackExtraShort);
      expect(key(right), PlayerAction.jumpForwardShort);
      expect(key(right, alt: true), PlayerAction.jumpForwardShort);
      expect(key(left, primary: true), PlayerAction.jumpBackMedium);
      expect(
        key(right, primary: true, alt: true),
        PlayerAction.jumpForwardLong,
      );
      expect(key(right, shift: true, primary: true), isNull);
    });

    test('letters keep VLC meanings, not the old K/L bindings', () {
      expect(key(LogicalKeyboardKey.space), PlayerAction.togglePlay);
      expect(key(LogicalKeyboardKey.keyK), PlayerAction.audioDelayUp);
      expect(key(LogicalKeyboardKey.keyJ), PlayerAction.audioDelayDown);
      expect(key(LogicalKeyboardKey.keyH), PlayerAction.subtitleDelayUp);
      expect(key(LogicalKeyboardKey.keyG), PlayerAction.subtitleDelayDown);
      expect(key(LogicalKeyboardKey.keyL), PlayerAction.cycleRepeat);
      expect(key(LogicalKeyboardKey.keyS), PlayerAction.stop);
      expect(key(LogicalKeyboardKey.keyS, shift: true), PlayerAction.snapshot);
      expect(key(LogicalKeyboardKey.keyV), PlayerAction.nextSubtitle);
      expect(
        key(LogicalKeyboardKey.keyV, alt: true),
        PlayerAction.previousSubtitle,
      );
      expect(
        key(LogicalKeyboardKey.keyV, shift: true),
        PlayerAction.toggleSubtitles,
      );
      expect(key(LogicalKeyboardKey.keyB), PlayerAction.nextAudioTrack);
      expect(key(LogicalKeyboardKey.keyF), PlayerAction.toggleFullscreen);
      expect(
        key(LogicalKeyboardKey.keyT, primary: true),
        PlayerAction.jumpToTime,
      );
      expect(
        key(LogicalKeyboardKey.keyO, primary: true),
        PlayerAction.openFile,
      );
    });

    test('speed keys: + − ] [ =', () {
      expect(key(LogicalKeyboardKey.equal, shift: true), PlayerAction.faster);
      expect(key(LogicalKeyboardKey.equal), PlayerAction.normalSpeed);
      expect(key(LogicalKeyboardKey.minus), PlayerAction.slower);
      expect(key(LogicalKeyboardKey.bracketRight), PlayerAction.fasterFine);
      expect(key(LogicalKeyboardKey.bracketLeft), PlayerAction.slowerFine);
    });

    test('the non-primary modifier never triggers a shortcut', () {
      expect(key(LogicalKeyboardKey.space, other: true), isNull);
      expect(key(LogicalKeyboardKey.space, primary: true), isNull);
    });

    test('F1–F10 jump to quick bookmarks; with Mod they set them', () {
      final jump = resolvePlayerKey(
        LogicalKeyboardKey.f3,
        shift: false,
        alt: false,
        primary: false,
        otherModifier: false,
      )!;
      expect(jump.bookmarkSlot, 2);
      expect(jump.setBookmark, isFalse);
      final set = resolvePlayerKey(
        LogicalKeyboardKey.f10,
        shift: false,
        alt: false,
        primary: true,
        otherModifier: false,
      )!;
      expect(set.bookmarkSlot, 9);
      expect(set.setBookmark, isTrue);
    });

    test('labels use the platform modifier', () {
      expect(playerShortcutLabel(PlayerAction.jumpToTime, apple: true), '⌘T');
      expect(
        playerShortcutLabel(PlayerAction.jumpToTime, apple: false),
        'Ctrl+T',
      );
      expect(
        playerShortcutLabel(PlayerAction.snapshot, apple: false),
        'Shift+S',
      );
    });
  });

  group('video frame layout', () {
    const area = Size(1600, 900);
    const video = Size(1920, 800); // 2.4:1

    test('default fit leaves the native view to letterbox itself', () {
      expect(
        layoutVideo(area, video, const VideoFrameSettings()),
        const VideoLayout(area),
      );
    });

    test('fill covers the area', () {
      final layout = layoutVideo(
        area,
        video,
        const VideoFrameSettings(mode: VideoFitMode.fill),
      );
      expect(layout.size.height, 900);
      expect(layout.size.width, closeTo(2160, 0.01));
      expect(layout.scaleX, closeTo(1, 1e-9));
    });

    test('forced 4:3 stretches the source-ratio box', () {
      final layout = layoutVideo(
        area,
        video,
        const VideoFrameSettings(aspectIndex: 2),
      );
      // 4:3 inside 1600×900 → 1200×900 shown.
      expect(layout.size.height, 900);
      expect(layout.size.width * layout.scaleX, closeTo(1200, 0.01));
    });

    test('original size and zoom', () {
      final original = layoutVideo(
        area,
        video,
        const VideoFrameSettings(mode: VideoFitMode.original, zoom: 0.5),
      );
      expect(original.size, const Size(960, 400));
    });

    test('unknown video size keeps the full area', () {
      expect(
        layoutVideo(area, null, const VideoFrameSettings(aspectIndex: 1)),
        const VideoLayout(area),
      );
    });

    test('zoom steps cycle both ways', () {
      expect(nextZoomStep(1), 2);
      expect(nextZoomStep(2), 0.25);
      expect(nextZoomStep(0.25, reverse: true), 2);
    });
  });

  group('speed, A-B, delays and clock parsing', () {
    test('presets and limits', () {
      expect(nextSpeedPreset(1, faster: true), 1.25);
      expect(nextSpeedPreset(1, faster: false), 0.75);
      expect(nextSpeedPreset(4, faster: true), 4);
      expect(nextSpeedPreset(0.5, faster: false), 0.25);
      expect(clampSpeed(9), 4);
      expect(formatSpeed(1), '1×');
      expect(formatSpeed(1.25), '1.25×');
      expect(formatSpeed(0.5), '0.5×');
    });

    test('long-press boost: 2×, or +1× from 2× up, at most 8×', () {
      expect(boostSpeed(1), 2);
      expect(boostSpeed(1.75), 2);
      expect(boostSpeed(2), 3);
      expect(boostSpeed(7.5), 8);
    });

    test('A-B: set A, set B (ordered), loop back, clear', () {
      var ab = const AbLoop();
      ab = ab.advance(const Duration(seconds: 30));
      expect(ab.phase, AbPhase.aSet);
      ab = ab.advance(const Duration(seconds: 10));
      expect(ab.a, const Duration(seconds: 10));
      expect(ab.b, const Duration(seconds: 30));
      expect(ab.jumpFor(const Duration(seconds: 20)), isNull);
      expect(
        ab.jumpFor(const Duration(seconds: 30)),
        const Duration(seconds: 10),
      );
      expect(ab.advance(Duration.zero).phase, AbPhase.off);
    });

    test('delay labels and clock input', () {
      expect(formatDelay(const Duration(milliseconds: 300)), '+0.30 s');
      expect(formatDelay(const Duration(milliseconds: -50)), '-0.05 s');
      expect(formatDelay(Duration.zero), '0.00 s');
      expect(
        parseClock('1:23:45'),
        const Duration(hours: 1, minutes: 23, seconds: 45),
      );
      expect(parseClock('12:30'), const Duration(minutes: 12, seconds: 30));
      expect(parseClock('90'), const Duration(seconds: 90));
      expect(parseClock('1:x'), isNull);
      expect(parseClock('1:2:3:4'), isNull);
    });
  });
}
