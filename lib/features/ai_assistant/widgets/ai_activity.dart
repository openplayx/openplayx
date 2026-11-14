import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../services/conversations/conversation_coordinator.dart';
import '../models/ai_tool_labels.dart';
import 'ai_disclosure.dart';

/// Three dots, one highlighted in turn. Stepped by a timer rather than a
/// continuous animation: cheap, and static when animations are disabled.
class AiTypingDots extends StatefulWidget {
  const AiTypingDots({super.key, this.size = 6});
  final double size;
  @override
  State<AiTypingDots> createState() => _AiTypingDotsState();
}

class _AiTypingDotsState extends State<AiTypingDots> {
  Timer? _timer;
  int _active = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    _timer = MediaQuery.disableAnimationsOf(context)
        ? null
        : Timer.periodic(const Duration(milliseconds: 400), (_) {
            if (mounted) setState(() => _active = (_active + 1) % 3);
          });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = ShadTheme.of(context).colorScheme.mutedForeground;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(right: i < 2 ? widget.size * 0.6 : 0),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: color.withValues(alpha: i == _active ? 1 : 0.35),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

/// Elapsed time since [since], refreshed every second.
class AiElapsed extends StatefulWidget {
  const AiElapsed({super.key, required this.since, this.style});
  final DateTime? since;
  final TextStyle? style;
  @override
  State<AiElapsed> createState() => _AiElapsedState();
}

class _AiElapsedState extends State<AiElapsed> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final since = widget.since;
    if (since == null) return const SizedBox.shrink();
    return Text(
      AiToolLabels.elapsed(context, DateTime.now().difference(since)),
      style: widget.style,
    );
  }
}

/// The always-visible "still running" row at the end of a running turn:
/// what the agent is doing now, which step, and for how long.
class AiActivityRow extends StatelessWidget {
  const AiActivityRow({
    super.key,
    required this.turn,
    required this.activity,
    this.tool,
    this.step = 0,
  });
  final ConversationTurn turn;
  final String activity;
  final String? tool;
  final int step;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final muted = theme.textTheme.muted;
    return Semantics(
      liveRegion: true,
      label: AiToolLabels.activity(context, activity, tool),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const AiTypingDots(),
            Text(
              AiToolLabels.activity(context, activity, tool),
              style: theme.textTheme.small,
            ),
            if (step > 0) Text(AiToolLabels.step(context, step), style: muted),
            AiElapsed(since: turn.activitySince, style: muted),
          ],
        ),
      ),
    );
  }
}

/// The model's reasoning, folded behind a one-line header: "Thinking…"
/// shimmering while it streams, then how long it took. Tap to read it.
class AiReasoningBlock extends StatelessWidget {
  const AiReasoningBlock({
    super.key,
    required this.text,
    this.streaming = false,
    this.duration,
  });
  final String text;
  final bool streaming;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final body = text.trim();
    return AiDisclosure(
      active: streaming,
      leading: streaming ? const AiSpinner() : null,
      label: Text(
        AiToolLabels.reasoning(
          context,
          streaming: streaming,
          duration: duration,
        ),
      ),
      body: body.isEmpty
          ? null
          : Container(
              margin: const EdgeInsets.only(top: 2, bottom: 6),
              padding: const EdgeInsetsDirectional.only(start: 12),
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: theme.colorScheme.border, width: 2),
                ),
              ),
              child: SelectableText(
                body,
                style: theme.textTheme.muted.copyWith(height: 1.5),
              ),
            ),
    );
  }
}
