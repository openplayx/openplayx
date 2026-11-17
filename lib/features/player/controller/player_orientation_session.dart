import 'package:flutter/services.dart';

import '../model/player_orientation.dart';

/// Keeps orientation requests ordered and restores the OS default on exit.
class PlayerOrientationSession {
  Future<void> _pending = Future.value();
  bool _changed = false;

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
    if (!_changed) return;
    await _request(const []);
    _changed = false;
  }
}
