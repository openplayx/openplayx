import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../ui/tokens/app_metrics.dart';

abstract final class AppTheme {
  static const _fontFallback = [
    'PingFang SC',
    'PingFang TC',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'sans-serif',
  ];
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
            fontFamilyFallback: _fontFallback,
          )
          .copyWith(
            muted: ShadTextTheme().muted.copyWith(
              color: colors.mutedForeground,
              fontFamilyFallback: _fontFallback,
            ),
          ),
      // Entered text in full foreground, hints clearly lighter: a hint must
      // never look like a value that is already filled in. (shadcn_ui
      // otherwise renders both in the muted color.)
      inputTheme: ShadInputTheme(
        style: TextStyle(color: colors.foreground),
        placeholderStyle: TextStyle(color: hintColor(brightness)),
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
      // Feedback appearance shared by every AppAlert / showAppToast
      // (ui/components/feedback). Unset fields keep shadcn_ui defaults.
      primaryAlertTheme: const ShadAlertTheme(
        iconPadding: EdgeInsetsDirectional.only(end: 12),
      ),
      destructiveAlertTheme: const ShadAlertTheme(
        iconPadding: EdgeInsetsDirectional.only(end: 12),
      ),
      // Toasts at the top centre: form buttons sit bottom right (desktop) or
      // at the bottom (phone), and page actions top right, so a toast there
      // never covers what the user may tap next. Safe-area aware by default.
      primaryToastTheme: const ShadToastTheme(
        alignment: _toastAlignment,
        duration: _toastDuration,
      ),
      destructiveToastTheme: const ShadToastTheme(
        alignment: _toastAlignment,
        duration: _toastDuration,
      ),
    );
  }

  /// Input hint color. Hints only carry examples or defaults (every field
  /// has its own label), so they favour telling "empty" from "filled" over
  /// their own readability: about 7.5:1 against entered text, like
  /// Tailwind's gray-400 / Apple's placeholder style.
  static Color hintColor(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFF52525B) // zinc-600
      : const Color(0xFFA1A1AA); // zinc-400

  static const _toastDuration = Duration(seconds: 5);
  static const _toastAlignment = Alignment.topCenter;

  static final light = build(Brightness.light);
  static final dark = build(Brightness.dark);
}
