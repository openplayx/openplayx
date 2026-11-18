import 'package:flutter/services.dart';

import '../model/player_orientation.dart';

/// Keeps orientation requests ordered and restores the OS default on exit.
class PlayerOrientationSession {
  Future<void> _pending = Future.value();
  bool _changed = false;
  bool _active = false;
  bool get active => _active;
  bool _followSystem = true;
  String? _deviceOrientation;

  Future<void> start({
    required bool followSystem,
    required PlayerScreenOrientation current,
  }) {
    _active = true;
    _followSystem = followSystem;
    return apply(followSystem ? PlayerScreenOrientation.system : current);
  }

  Future<void> setFollowSystem(
    bool followSystem,
    PlayerScreenOrientation current,
  ) async {
    if (_followSystem == followSystem || !_active) return;
    _followSystem = followSystem;
    await apply(followSystem ? PlayerScreenOrientation.system : current);
  }

  // Physical direction events are independent of the locked Flutter viewport.
  // The initial reading establishes a baseline; only a later change releases
  // a manual lock. Face-up/down readings are filtered by the native adapters.
  Future<void> deviceOrientationChanged(String orientation) async {
    final previous = _deviceOrientation;
    _deviceOrientation = orientation;
    if (!_active ||
        !_followSystem ||
        previous == null ||
        previous == orientation) {
      return;
    }
    await apply(PlayerScreenOrientation.system);
  }

  Future<void> _request(List<DeviceOrientation> orientations) {
    final request = _pending.then(
      (_) => SystemChrome.setPreferredOrientations(orientations),
    );
    // A failed request must not block a later restore.
    _pending = request.catchError((Object _) {});
    return request;
  }

  Future<void> apply(PlayerScreenOrientation orientation) {
    _changed = true;
    return _request(orientation.orientations);
  }

  Future<void> restore() async {
    _active = false;
    if (!_changed) return;
    _changed = false;
    try {
      await _request(const []);
    } catch (_) {
      _changed = true;
      rethrow;
    }
  }
}
