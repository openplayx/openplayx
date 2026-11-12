import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../icons/app_icons.dart';

/// Provides the app-wide assistant entry to the pages below it. Each page
/// draws the button in its own header, so it moves with the page during
/// route transitions instead of floating above them.
class AssistantAction extends InheritedWidget {
  const AssistantAction({
    super.key,
    required this.label,
    required this.onPressed,
    required super.child,
  });

  final String label;
  final VoidCallback onPressed;

  static AssistantAction? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AssistantAction>();

  @override
  bool updateShouldNotify(AssistantAction old) =>
      label != old.label || onPressed != old.onPressed;
}

/// The assistant button for the nearest [AssistantAction]; empty without one.
class AssistantButton extends StatelessWidget {
  const AssistantButton({super.key, this.size = 40, this.builder});

  final double size;

  /// Optional custom look (e.g. a filled circle over artwork).
  final Widget Function(BuildContext context, AssistantAction action)? builder;

  @override
  Widget build(BuildContext context) {
    final action = AssistantAction.maybeOf(context);
    if (action == null) return const SizedBox.shrink();
    return Tooltip(
      message: action.label,
      child: Semantics(
        label: action.label,
        button: true,
        excludeSemantics: true,
        child:
            builder?.call(context, action) ??
            ShadIconButton.ghost(
              width: size,
              height: size,
              icon: const Icon(AppIcons.assistant),
              onPressed: action.onPressed,
            ),
      ),
    );
  }
}
