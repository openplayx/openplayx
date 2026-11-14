import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/icons/app_icons.dart';
import '../../../ui/tokens/app_motion.dart';

/// Light band sweeping across muted text while a step is still running.
/// Static when animations are disabled.
class AiShimmer extends StatefulWidget {
  const AiShimmer({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<AiShimmer> createState() => _AiShimmerState();
}

class _AiShimmerState extends State<AiShimmer>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  static const _curve = Cubic(0.7, 0, 1, 0.4);

  void _sync(bool animate) {
    if (animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(widget.enabled && !MediaQuery.disableAnimationsOf(context));
  }

  @override
  void didUpdateWidget(AiShimmer old) {
    super.didUpdateWidget(old);
    _sync(widget.enabled && !MediaQuery.disableAnimationsOf(context));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isAnimating) return widget.child;
    final colors = ShadTheme.of(context).colorScheme;
    final base = colors.mutedForeground;
    // Lighter than the text in light mode, darker in dark mode.
    final highlight = Color.lerp(base, colors.background, 0.7)!;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          // A gradient twice the text's width whose bright centre travels
          // from the left edge to one width past the right edge.
          final w = bounds.width, t = _curve.transform(_controller.value);
          return LinearGradient(
            begin: const Alignment(-1, -0.3),
            end: const Alignment(1, 0.3),
            colors: [base, base, highlight, base, base],
            stops: const [0, 0.43, 0.5, 0.57, 1],
          ).createShader(
            Rect.fromLTWH(-w + 2 * w * t, 0, 2 * w, bounds.height),
          );
        },
        child: child,
      ),
    );
  }
}

/// Small ring spinner with a faint track.
class AiSpinner extends StatelessWidget {
  const AiSpinner({super.key, this.size = 14});
  final double size;
  @override
  Widget build(BuildContext context) {
    final color = ShadTheme.of(context).colorScheme.mutedForeground;
    if (MediaQuery.disableAnimationsOf(context)) {
      return Icon(AppIcons.loading, size: size, color: color);
    }
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color,
        backgroundColor: color.withValues(alpha: 0.25),
      ),
    );
  }
}

/// A one-line muted header that folds a body open below it: the shape used
/// for reasoning and tool steps. [trailing] replaces the chevron (e.g. with
/// approve / deny buttons); without a [body] there is nothing to toggle.
class AiDisclosure extends StatefulWidget {
  const AiDisclosure({
    super.key,
    required this.label,
    this.leading,
    this.trailing,
    this.body,
    this.active = false,
    this.initiallyExpanded = false,
    this.fill = false,
  });
  final Widget label;
  final Widget? leading, trailing, body;

  /// Still running: the label shimmers.
  final bool active;
  final bool initiallyExpanded;

  /// Stretch the header so the chevron sits at the far edge.
  final bool fill;
  @override
  State<AiDisclosure> createState() => _AiDisclosureState();
}

class _AiDisclosureState extends State<AiDisclosure> {
  late bool _expanded = widget.initiallyExpanded;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colors = theme.colorScheme;
    final canToggle = widget.body != null;
    final color = _hover && canToggle
        ? colors.foreground
        : colors.mutedForeground;
    final label = DefaultTextStyle.merge(
      style: theme.textTheme.small.copyWith(
        color: color,
        fontWeight: FontWeight.w400,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: AiShimmer(enabled: widget.active, child: widget.label),
    );
    final trailing =
        widget.trailing ??
        (canToggle
            ? Icon(
                _expanded ? AppIcons.collapse : AppIcons.expand,
                size: 14,
                color: color,
              )
            : null);
    final header = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: widget.fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: 6),
          ],
          if (widget.fill) Expanded(child: label) else Flexible(child: label),
          if (trailing != null) ...[const SizedBox(width: 6), trailing],
        ],
      ),
    );
    final body = widget.body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: !canToggle
              ? header
              : Semantics(
                  button: true,
                  expanded: _expanded,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _hover = true),
                    onExit: (_) => setState(() => _hover = false),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: header,
                    ),
                  ),
                ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: AppMotion.duration(
              context,
              const Duration(milliseconds: 300),
            ),
            curve: Curves.easeOutQuint,
            alignment: AlignmentDirectional.topStart,
            child: _expanded && body != null
                ? body
                : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );
  }
}
