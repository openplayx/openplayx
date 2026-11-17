import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Makes the centre button of a TV remote (D-pad select) press whatever is
/// focused, the way Enter does on a keyboard.
///
/// Material widgets already treat select as activation, but shadcn widgets
/// only bind Enter and Space. When nothing below handles a select key, this
/// replays it as Enter along the focus chain, so every focusable control
/// works with a remote without per-widget changes.
class RemoteSelectAsEnter extends StatefulWidget {
  const RemoteSelectAsEnter({super.key, required this.child});
  final Widget child;

  @override
  State<RemoteSelectAsEnter> createState() => _RemoteSelectAsEnterState();
}

class _RemoteSelectAsEnterState extends State<RemoteSelectAsEnter> {
  final FocusNode _node = FocusNode(
    debugLabel: 'RemoteSelectAsEnter',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.select &&
        event.logicalKey != LogicalKeyboardKey.gameButtonA) {
      return KeyEventResult.ignored;
    }
    final enter = switch (event) {
      KeyDownEvent() => KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: event.timeStamp,
        synthesized: true,
      ),
      KeyRepeatEvent() => KeyRepeatEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: event.timeStamp,
      ),
      _ => KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: event.timeStamp,
        synthesized: true,
      ),
    };
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return KeyEventResult.ignored;
    for (final target in [primary, ...primary.ancestors]) {
      if (identical(target, _node)) continue;
      final result = target.onKeyEvent?.call(target, enter);
      if (result == KeyEventResult.handled) return KeyEventResult.handled;
      if (result == KeyEventResult.skipRemainingHandlers) break;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _node, onKeyEvent: _onKey, child: widget.child);
}
