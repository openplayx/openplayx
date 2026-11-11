import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Swiping the row to the left reveals [action] (one or more buttons) behind
/// its trailing edge, like iOS list rows. Tapping the row while open closes it.
class SwipeReveal extends StatefulWidget {
  const SwipeReveal({
    super.key,
    required this.child,
    required this.action,
    this.actionWidth = 88,
    this.trailingInset = 0,
    this.enabled = true,
  });
  final Widget child;

  /// Built with a callback that closes the row, e.g. before a confirmation.
  final Widget Function(VoidCallback close) action;
  final double actionWidth;

  /// Transparent padding at the child's trailing edge. The row slides that
  /// much less, so its visible content meets the actions without a gap.
  final double trailingInset;
  double get _slide => actionWidth - trailingInset;
  final bool enabled;
  @override
  State<SwipeReveal> createState() => _SwipeRevealState();
}

class _SwipeRevealState extends State<SwipeReveal>
    with SingleTickerProviderStateMixin {
  late final _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void didUpdateWidget(SwipeReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _open.value = 0;
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  void _close() => _open.animateTo(0);

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragUpdate: !widget.enabled
        ? null
        : (d) => _open.value -= (d.primaryDelta ?? 0) / widget._slide,
    onHorizontalDragEnd: !widget.enabled
        ? null
        : (d) {
            final velocity = d.primaryVelocity ?? 0;
            final open =
                velocity < -300 || (velocity <= 300 && _open.value > 0.5);
            _open.animateTo(open ? 1 : 0);
          },
    child: ClipRect(
      child: AnimatedBuilder(
        animation: _open,
        builder: (context, child) => Stack(
          children: [
            if (_open.value > 0)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: widget.actionWidth,
                child: widget.action(_close),
              ),
            Transform.translate(
              offset: Offset(-_open.value * widget._slide, 0),
              child: _open.value > 0
                  // While open, a tap on the row only closes it.
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _close,
                      child: AbsorbPointer(child: child),
                    )
                  : child,
            ),
          ],
        ),
        child: widget.child,
      ),
    ),
  );
}

/// One button in a [SwipeActionBar].
class SwipeAction {
  const SwipeAction({
    required this.label,
    required this.onPressed,
    this.destructive = false,
    this.key,
  });
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final bool destructive;
  final Key? key;
}

/// The buttons a [SwipeReveal] uncovers, each [width] wide; the row closes
/// before an action runs.
class SwipeActionBar extends StatelessWidget {
  const SwipeActionBar({super.key, required this.actions, required this.close});
  static const width = 96.0;
  final List<SwipeAction> actions;
  final VoidCallback close;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final a in actions)
        SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
            child:
                (a.destructive ? ShadButton.destructive : ShadButton.secondary)(
                  key: a.key,
                  height: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  enabled: a.onPressed != null,
                  onPressed: a.onPressed == null
                      ? null
                      : () {
                          close();
                          a.onPressed!();
                        },
                  // Long labels (or translations) shrink, never overflow.
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(a.label)),
                ),
          ),
        ),
    ],
  );
}
