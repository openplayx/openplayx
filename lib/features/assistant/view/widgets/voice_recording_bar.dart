import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../ui/icons/app_icons.dart';
import '../../controller/voice_input_controller.dart';

/// Elapsed recording time as `m:ss`, refreshed while the recording runs.
class VoiceElapsed extends StatefulWidget {
  const VoiceElapsed({super.key, required this.stopwatch, this.style});
  final Stopwatch stopwatch;
  final TextStyle? style;
  @override
  State<VoiceElapsed> createState() => _VoiceElapsedState();
}

class _VoiceElapsedState extends State<VoiceElapsed> {
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.stopwatch.elapsed.inSeconds;
    return Text(
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
      style: widget.style?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Live input waveform: newest sample on the right, silence drawn as dots and
/// speech as rounded bars, padded with dots on the left like an idle line.
class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({super.key, required this.levels, required this.color});
  final ValueListenable<List<double>> levels;
  final Color color;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<double>>(
    valueListenable: levels,
    builder: (context, values, _) => CustomPaint(
      size: const Size(double.infinity, 28),
      painter: _WaveformPainter(values, color),
    ),
  );
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.levels, this.color);
  final List<double> levels;
  final Color color;
  static const _step = 6.0, _bar = 3.0, _silence = 0.08;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final quiet = Paint()..color = color.withValues(alpha: 0.45);
    final count = math.max(1, (size.width / _step).floor());
    final mid = size.height / 2;
    for (var i = 0; i < count; i++) {
      // Right-align samples: slot (count - 1) is the newest.
      final index = levels.length - count + i;
      final level = index >= 0 ? levels[index] : 0.0;
      final x = size.width - (count - i) * _step + _step / 2;
      if (level < _silence) {
        canvas.drawCircle(Offset(x, mid), 1.6, quiet);
      } else {
        final h = math.max(_bar * 2, level * size.height);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, mid), width: _bar, height: h),
            const Radius.circular(_bar / 2),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.levels != levels || old.color != color;
}

/// Replaces the text field while dictating: discard, timer, waveform, stop
/// (transcribe into the draft) and send (transcribe then send).
class VoiceRecordingBar extends StatelessWidget {
  const VoiceRecordingBar({
    super.key,
    required this.voice,
    required this.cancelLabel,
    required this.stopLabel,
    required this.sendLabel,
    required this.statusLabel,
    required this.onStop,
    required this.onSend,
  });
  final VoiceInputController voice;
  final String cancelLabel, stopLabel, sendLabel;

  /// Shown instead of the waveform while preparing or transcribing.
  final String? statusLabel;
  final VoidCallback? onStop, onSend;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context), colors = theme.colorScheme;
    final recording = voice.state == VoiceInputState.recording;
    Widget button(
      String label,
      IconData icon,
      VoidCallback? onPressed, {
      required Color background,
      required Color foreground,
      double size = 18,
    }) => Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: ShadIconButton(
          width: 36,
          height: 36,
          enabled: onPressed != null,
          decoration: const ShadDecoration(shape: BoxShape.circle),
          backgroundColor: onPressed == null ? colors.muted : background,
          hoverBackgroundColor: background.withValues(alpha: 0.85),
          foregroundColor: onPressed == null
              ? colors.mutedForeground
              : foreground,
          icon: Icon(icon, size: size),
          onPressed: onPressed,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          button(
            cancelLabel,
            AppIcons.delete,
            voice.state == VoiceInputState.cancelling ? null : voice.cancel,
            background: Colors.transparent,
            foreground: colors.foreground,
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 44,
            child: VoiceElapsed(
              stopwatch: voice.elapsed,
              style: theme.textTheme.small.copyWith(
                color: colors.mutedForeground,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: statusLabel == null
                ? VoiceWaveform(levels: voice.levels, color: colors.foreground)
                : Row(
                    children: [
                      SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.mutedForeground,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          statusLabel!,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.small.copyWith(
                            color: colors.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          button(
            stopLabel,
            Icons.stop_rounded,
            recording ? onStop : null,
            background: colors.muted,
            foreground: colors.foreground,
            size: 20,
          ),
          const SizedBox(width: 6),
          button(
            sendLabel,
            AppIcons.sendUp,
            recording ? onSend : null,
            background: colors.foreground,
            foreground: colors.background,
          ),
        ],
      ),
    );
  }
}
