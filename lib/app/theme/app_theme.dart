import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../ui/tokens/app_metrics.dart';

abstract final class AppTheme {
  static ShadThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = dark
        ? const ShadZincColorScheme.dark(
            primary: Color(0xFF67D9BD),
            primaryForeground: Color(0xFF082F28),
            ring: Color(0xFF67D9BD),
          )
        : const ShadZincColorScheme.light(
            primary: Color(0xFF116953),
            primaryForeground: Color(0xFFFFFFFF),
            ring: Color(0xFF116953),
          );
    return ShadThemeData(
      brightness: brightness,
      colorScheme: colors,
      radius: AppMetrics.controlRadius,
      textTheme: ShadTextTheme(family: 'Geist', package: 'shadcn_ui')
          .apply(
            displayColor: colors.foreground,
            bodyColor: colors.foreground,
            fontFamilyFallback: const [
              'PingFang SC',
              'PingFang TC',
              'Microsoft YaHei',
              'Noto Sans CJK SC',
              'sans-serif',
            ],
          )
          .copyWith(
            muted: ShadTextTheme().muted.copyWith(
              color: colors.mutedForeground,
            ),
          ),
      primaryButtonTheme: const ShadButtonTheme(height: AppMetrics.touchTarget),
      secondaryButtonTheme: const ShadButtonTheme(
        height: AppMetrics.touchTarget,
      ),
      outlineButtonTheme: ShadButtonTheme(
        height: AppMetrics.touchTarget,
        foregroundColor: colors.foreground,
        hoverForegroundColor: colors.accentForeground,
      ),
      ghostButtonTheme: ShadButtonTheme(
        height: AppMetrics.touchTarget,
        foregroundColor: colors.foreground,
        hoverForegroundColor: colors.accentForeground,
      ),
      destructiveButtonTheme: const ShadButtonTheme(
        height: AppMetrics.touchTarget,
      ),
      cardTheme: const ShadCardTheme(
        radius: AppMetrics.panelRadius,
        padding: EdgeInsets.all(16),
      ),
    );
  }

  static final light = build(Brightness.light);
  static final dark = build(Brightness.dark);
}
