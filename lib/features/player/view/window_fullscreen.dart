import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native window full screen on desktop. Each Flutter window (main and
/// player windows) answers on its own engine's `openplayx/window` channel.
/// Platforms without the native handler report [isSupported] false and the
/// player hides its full-screen control.
class WindowFullscreen {
  WindowFullscreen({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('openplayx/window');
  final MethodChannel _channel;
  bool _supported = true;

  /// Called when the user changes full screen natively (green button,
  /// system shortcut), so the player's state follows.
  void listen(ValueChanged<bool> onChanged) {
    if (!isSupported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'fullScreenChanged') onChanged(call.arguments == true);
    });
  }

  void stopListening() {
    if (isSupported) _channel.setMethodCallHandler(null);
  }

  bool get isSupported =>
      _supported &&
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux => true,
        _ => false,
      };

  Future<bool> isFullscreen() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isFullScreen') ?? false;
    } on MissingPluginException {
      _supported = false;
      return false;
    }
  }

  /// Sets full screen and returns the resulting state.
  Future<bool> setFullscreen(bool value) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('setFullScreen', value) ?? value;
    } on MissingPluginException {
      _supported = false;
      return false;
    }
  }
}
