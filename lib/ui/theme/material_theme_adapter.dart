import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Retains the library-generated Material infrastructure and text mappings.
abstract final class MaterialThemeAdapter {
  static ThemeData adapt(BuildContext context) {
    final shad = ShadTheme.of(context);
    return Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.copyWith(
        headlineSmall: shad.textTheme.h3,
        titleLarge: shad.textTheme.h4,
        bodyMedium: shad.textTheme.p,
        bodySmall: shad.textTheme.muted,
      ),
      splashFactory: NoSplash.splashFactory,
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: shad.colorScheme.popover,
          borderRadius: shad.radius,
          border: Border.all(color: shad.colorScheme.border),
        ),
        textStyle: shad.textTheme.small.copyWith(
          color: shad.colorScheme.popoverForeground,
        ),
      ),
    );
  }
}
