import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../ui/tokens/app_metrics.dart';

ChatTheme flyerChatTheme(ShadThemeData theme) {
  final c = theme.colorScheme, t = theme.textTheme;
  return ChatTheme(
    colors: ChatColors(
      primary: c.primary,
      onPrimary: c.primaryForeground,
      surface: c.background,
      onSurface: c.foreground,
      surfaceContainer: c.card,
      surfaceContainerLow: c.muted,
      surfaceContainerHigh: c.accent,
    ),
    typography: ChatTypography(
      bodyLarge: t.p,
      bodyMedium: t.p,
      bodySmall: t.muted,
      labelLarge: t.small,
      labelMedium: t.small,
      labelSmall: t.muted,
    ),
    shape: AppMetrics.panelRadius,
  );
}
