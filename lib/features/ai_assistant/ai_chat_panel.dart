import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<void> showAiChatPanel(
  BuildContext context, {
  required WidgetBuilder builder,
  bool playing = false,
}) async {
  final size = MediaQuery.sizeOf(context);
  final wide = size.width >= 840;
  await showShadSheet<void>(
    context: context,
    useRootNavigator: true,
    side: wide
        ? ShadSheetSide.right
        : playing
        ? ShadSheetSide.top
        : ShadSheetSide.bottom,
    builder: (context) => ShadSheet(
      padding: EdgeInsets.zero,
      child: SafeArea(
        child: SizedBox(
          width: wide ? 520 : size.width,
          height:
              (size.height -
                      MediaQuery.viewInsetsOf(context).bottom -
                      (playing ? 160 : 48))
                  .clamp(180, size.height) *
              (wide ? 1 : 0.9),
          child: builder(context),
        ),
      ),
    ),
  );
}
