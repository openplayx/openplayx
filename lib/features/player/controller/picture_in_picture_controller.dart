import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A per-player bridge. Desktop runners register it only on player windows;
/// Android uses its activity and iOS uses the current engine's video output.
class PictureInPictureController extends ChangeNotifier {
  PictureInPictureController({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('openplayx/picture_in_picture');

  final MethodChannel _channel;
  bool supported = false;
  bool active = false;
  bool entering = false;
  bool restoring = false;
  bool _disposed = false;

  bool get keepsPlaying => active || entering || restoring;

  Future<void> initialize() async {
    _channel.setMethodCallHandler((call) async {
      if (_disposed) return;
      if (call.method == 'changed') {
        active = call.arguments == true;
        entering = false;
        restoring = false;
        notifyListeners();
      } else if (call.method == 'restoring') {
        active = false;
        entering = false;
        restoring = true;
        notifyListeners();
      } else if (call.method == 'closed') {
        active = entering = restoring = false;
        notifyListeners();
      }
    });
    try {
      supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      supported = false;
    } on PlatformException {
      supported = false;
    }
    if (!_disposed) notifyListeners();
  }

  void completeRestore() {
    if (!restoring) return;
    restoring = false;
    notifyListeners();
  }

  /// Hide mobile chrome before the system captures the activity's first frame.
  void prepare() {
    entering = true;
    notifyListeners();
  }

  Future<void> enter({required double aspectRatio, int? handle}) async {
    try {
      final accepted = await _channel.invokeMethod<bool>('enter', {
        'aspectRatio': aspectRatio,
        if (handle != null) 'handle': handle.toString(),
      });
      if (accepted != true) throw StateError('Picture in picture unavailable');
      // `changed` is authoritative: acceptance can precede the OS transition.
    } catch (_) {
      entering = false;
      if (!_disposed) notifyListeners();
      rethrow;
    }
  }

  Future<void> exit() async {
    await _channel.invokeMethod<void>('exit');
  }

  @override
  void dispose() {
    _disposed = true;
    if (keepsPlaying) {
      _channel.invokeMethod<void>('exit').catchError((Object _) {});
    }
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}
