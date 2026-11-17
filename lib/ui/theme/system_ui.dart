import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Transparent system bars that blend into the page, with icons that contrast
/// with [background]. Contrast enforcement is off so Android does not lay a
/// grey scrim over the status and navigation bars.
SystemUiOverlayStyle appSystemUiStyle(Brightness background) {
  final dark = background == Brightness.dark;
  final icons = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: const Color(0x00000000),
    statusBarIconBrightness: icons,
    // iOS reads the bar's background brightness instead of the icon colour.
    statusBarBrightness: background,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: const Color(0x00000000),
    systemNavigationBarDividerColor: const Color(0x00000000),
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarContrastEnforced: false,
  );
}

/// Draws the app under the status and navigation bars on Android, so pages
/// reach the screen edges like other modern apps.
Future<void> enableEdgeToEdge() async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (error) {
    debugPrint('Could not enable edge-to-edge: $error');
  }
}
