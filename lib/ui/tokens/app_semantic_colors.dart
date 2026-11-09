import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Additional semantic pairs; library colors stay in ShadColorScheme.
class AppSemanticColors {
  const AppSemanticColors({
    required this.success,
    required this.successSurface,
    required this.warning,
    required this.warningSurface,
    required this.info,
    required this.infoSurface,
  });
  final Color success,
      successSurface,
      warning,
      warningSurface,
      info,
      infoSurface;
  static const playerSurface = Color(0xFF09090B);
  static const playerForeground = Color(0xFFFAFAFA);
  static const playerMuted = Color(0xFFB5B5BE);
  static const playerOverlay = Color(0xD909090B);
  static const playerScrim = Color(0x9909090B);
  static AppSemanticColors of(BuildContext context) =>
      ShadTheme.of(context).brightness == Brightness.dark ? dark : light;
  static const light = AppSemanticColors(
    success: Color(0xFF166534),
    successSurface: Color(0xFFDCFCE7),
    warning: Color(0xFF854D0E),
    warningSurface: Color(0xFFFEF9C3),
    info: Color(0xFF1E40AF),
    infoSurface: Color(0xFFDBEAFE),
  );
  static const dark = AppSemanticColors(
    success: Color(0xFF86EFAC),
    successSurface: Color(0xFF14532D),
    warning: Color(0xFFFDE047),
    warningSurface: Color(0xFF713F12),
    info: Color(0xFF93C5FD),
    infoSurface: Color(0xFF1E3A8A),
  );
}
