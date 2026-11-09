import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../tokens/app_metrics.dart';

/// A seek bar previews continuously and commits once on release. The entire
/// 48px lane is interactive; the visual track remains thin over the video.
class PlaybackProgress extends StatefulWidget {
  const PlaybackProgress({
    super.key,
    required this.value,
    required this.max,
    required this.enabled,
    required this.label,
    required this.onPreview,
    required this.onCommit,
  });
  final double value, max;
  final bool enabled;
  final String label;
  final ValueChanged<double> onPreview, onCommit;
  @override
  State<PlaybackProgress> createState() => _PlaybackProgressState();
}

class _PlaybackProgressState extends State<PlaybackProgress> {
  late final _slider = ShadSliderController(initialValue: widget.value);
  bool _focused = false;
  double? _preview;
  double get _max => widget.max > 0 ? widget.max : 1;
  @override
  void didUpdateWidget(covariant PlaybackProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_preview == null) _slider.value = widget.value.clamp(0, _max);
  }

  void _change(double value) {
    _preview = value.clamp(0, _max);
    _slider.value = _preview!;
    widget.onPreview(_preview!);
  }

  void _commit() {
    if (_preview == null) return;
    final value = _preview!;
    _preview = null;
    widget.onCommit(value);
  }

  void _step(double delta) {
    _change(widget.value + delta);
    _commit();
  }

  @override
  void dispose() {
    _slider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    slider: true,
    enabled: widget.enabled,
    value: '${(widget.value / _max * 100).round()}%',
    increasedValue:
        '${((widget.value + 5000).clamp(0, _max) / _max * 100).round()}%',
    decreasedValue:
        '${((widget.value - 5000).clamp(0, _max) / _max * 100).round()}%',
    onIncrease: widget.enabled ? () => _step(5000) : null,
    onDecrease: widget.enabled ? () => _step(-5000) : null,
    child: Focus(
      canRequestFocus: widget.enabled,
      onFocusChange: (value) => setState(() => _focused = value),
      onKeyEvent: (_, event) {
        if (!widget.enabled || event is KeyUpEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _step(-5000);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _step(5000);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, box) {
          double position(Offset local) => local.dx / box.maxWidth * _max;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.enabled
                ? (event) {
                    _change(position(event.localPosition));
                    _commit();
                  }
                : null,
            onHorizontalDragStart: widget.enabled
                ? (event) => _change(position(event.localPosition))
                : null,
            onHorizontalDragUpdate: widget.enabled
                ? (event) => _change(position(event.localPosition))
                : null,
            onHorizontalDragEnd: widget.enabled ? (_) => _commit() : null,
            onHorizontalDragCancel: () {
              _preview = null;
              _slider.value = widget.value;
            },
            child: Container(
              height: AppMetrics.touchTarget,
              decoration: _focused
                  ? BoxDecoration(
                      border: Border.all(
                        color: ShadTheme.of(context).colorScheme.ring,
                      ),
                      borderRadius: AppMetrics.controlRadius,
                    )
                  : null,
              child: Center(
                child: ExcludeFocus(
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: ShadSlider(
                        controller: _slider,
                        max: _max,
                        enabled: widget.enabled,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
