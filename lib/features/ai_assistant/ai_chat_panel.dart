import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Opens the assistant as a full page that slides in from the right (with
/// edge-swipe back), above the tabs and the player.
Future<void> showAiChatPage(
  BuildContext context, {
  required Widget Function(BuildContext context, VoidCallback close) builder,
}) => Navigator.of(context, rootNavigator: true).push<void>(
  CupertinoPageRoute<void>(
    settings: const RouteSettings(name: aiChatRouteName),
    builder: (context) => Scaffold(
      body: SafeArea(
        child: builder(context, () => Navigator.of(context).maybePop()),
      ),
    ),
  ),
);

const aiChatRouteName = 'ai-chat';
