import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Device interaction mode is independent of window size and attached keyboards.
/// OPX_TV is also useful for previewing the TV presentation on a desktop.
class AppExperience extends InheritedWidget {
  const AppExperience({
    super.key,
    required this.television,
    required super.child,
  });

  final bool television;
  static bool _nativeTelevision =
      const bool.fromEnvironment('OPX_TV') ||
      (!kIsWeb && Platform.operatingSystem == 'tvos');

  static Future<void> initialize() async {
    if (_nativeTelevision || kIsWeb || !Platform.isAndroid) return;
    try {
      _nativeTelevision =
          await const MethodChannel('openplayx/device_experience')
              .invokeMethod<bool>('isTelevision') ??
          false;
    } on MissingPluginException {
      // Older runners and widget tests can still use the explicit override.
    } on PlatformException {
      // A failed device query must not prevent startup on a phone.
    }
  }

  /// Non-listening lookup is safe in playback initialization/lifecycle methods.
  static bool isTelevision(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppExperience>()?.television ??
      _nativeTelevision;

  @override
  bool updateShouldNotify(AppExperience oldWidget) =>
      television != oldWidget.television;
}
