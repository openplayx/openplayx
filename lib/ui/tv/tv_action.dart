import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../tokens/app_motion.dart';

/// One remote target: visible focus, single activation, and scroll-into-view.
/// Descendants are excluded from traversal so a tile never has two stops.
class TvAction extends StatefulWidget {
  const TvAction({
    super.key,
    required this.child,
    required this.onPressed,
    this.label,
    this.autofocus = false,
    this.focusNode,
    this.selected = false,
    this.padding = const EdgeInsets.all(12),
  });
  final Widget child;
  final VoidCallback? onPressed;
  final String? label;
  final bool autofocus, selected;
  final FocusNode? focusNode;
  final EdgeInsetsGeometry padding;

  @override
  State<TvAction> createState() => _TvActionState();
}

class _TvActionState extends State<TvAction> {
  bool _focused = false;

  void _focusChanged(bool value) {
    setState(() => _focused = value);
    if (!value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focused) return;
      Scrollable.ensureVisible(
        context,
        duration: AppMotion.duration(context, AppMotion.feedback),
        alignment: .35,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      selected: widget.selected,
      label: widget.label,
      onTap: widget.onPressed,
      child: Focus(
        // Consume activation here, before the global select-as-enter fallback.
        onKeyEvent: (_, event) {
          if (!{
            LogicalKeyboardKey.select,
            LogicalKeyboardKey.enter,
            LogicalKeyboardKey.space,
            LogicalKeyboardKey.gameButtonA,
          }.contains(event.logicalKey)) {
            return KeyEventResult.ignored;
          }
          if (event is KeyDownEvent) widget.onPressed?.call();
          return KeyEventResult.handled;
        },
        canRequestFocus: false,
        skipTraversal: true,
        child: FocusableActionDetector(
          enabled: widget.onPressed != null,
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          onFocusChange: _focusChanged,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed?.call();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: widget.onPressed,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: AppMotion.duration(context, AppMotion.feedback),
              padding: widget.padding,
              decoration: BoxDecoration(
                color: _focused || widget.selected
                    ? colors.primary.withValues(alpha: .14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _focused ? colors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
              child: ExcludeFocus(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
