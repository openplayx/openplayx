import 'dart:math' as math;

import 'package:flutter/scheduler.dart';

/// Decouples how text arrives from how it is shown.
///
/// Model output lands in bursts (nothing for a while, then a few dozen
/// characters at once). Showing each burst as it lands reads as stutter. This
/// keeps a per-message cursor and advances it every frame at a rate
/// proportional to the backlog, so the visible text approaches the received
/// text exponentially: a steady trickle while text keeps flowing, a quick
/// catch-up after a large burst, and never more than about [catchUp] behind.
///
/// Only text first seen while still streaming is smoothed; history and text
/// that was already long when first seen are shown as-is.
class StreamTextSmoother {
  StreamTextSmoother(this._onChanged);
  final VoidCallback _onChanged;

  /// Time constant of the exponential catch-up.
  static const catchUp = Duration(milliseconds: 220);

  /// Floor so the tail of a reply does not crawl, in characters per second.
  static const minRate = 45.0;

  /// Text already this long when first seen live (a view opened mid-reply)
  /// is shown as-is rather than retyped.
  static const replayLimit = 200;

  final _shown = <String, double>{};
  final _targets = <String, int>{};
  Ticker? _ticker;
  Duration _last = Duration.zero;
  bool _disposed = false;

  /// The prefix of [text] to display for [id]. [live] means more text may
  /// still arrive for it.
  String view(String id, String text, {required bool live}) {
    var shown = _shown[id];
    if (shown == null) {
      if (!live || _disposed) return text;
      shown = text.length > replayLimit ? text.length.toDouble() : 0.0;
      _shown[id] = shown;
    }
    _targets[id] = text.length;
    final cursor = shown.floor();
    if (cursor >= text.length) {
      if (!live) _forget(id);
      return text;
    }
    _start();
    return text.substring(0, _boundary(text, cursor));
  }

  /// Whether [id] still has received text that is not on screen yet.
  bool revealing(String id) {
    final shown = _shown[id], target = _targets[id];
    return shown != null && target != null && shown.floor() < target;
  }

  void reset() {
    _shown.clear();
    _targets.clear();
    _ticker?.stop();
  }

  void dispose() {
    _disposed = true;
    _ticker?.dispose();
    _ticker = null;
  }

  void _forget(String id) {
    _shown.remove(id);
    _targets.remove(id);
  }

  void _start() {
    if (_disposed) return;
    final ticker = _ticker ??= Ticker(_tick, debugLabel: 'StreamTextSmoother');
    if (ticker.isActive) return;
    _last = Duration.zero;
    ticker.start();
  }

  void _tick(Duration elapsed) {
    final dt =
        (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    var changed = false, pending = false;
    for (final MapEntry(key: id, value: target) in _targets.entries) {
      final shown = _shown[id]!;
      final backlog = target - shown;
      if (backlog <= 0) continue;
      final rate = math.max(
        minRate,
        backlog * Duration.microsecondsPerSecond / catchUp.inMicroseconds,
      );
      final next = math.min(target.toDouble(), shown + rate * dt);
      if (next.floor() != shown.floor()) changed = true;
      _shown[id] = next;
      if (next < target) pending = true;
    }
    if (!pending) _ticker?.stop();
    if (changed) _onChanged();
  }

  /// Never split a UTF-16 surrogate pair (emoji, rare CJK).
  static int _boundary(String text, int cursor) {
    if (cursor <= 0 || cursor >= text.length) return cursor;
    final unit = text.codeUnitAt(cursor - 1);
    return unit >= 0xD800 && unit <= 0xDBFF ? cursor + 1 : cursor;
  }
}
