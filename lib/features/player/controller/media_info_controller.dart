import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openplayx_playback/playback.dart';

import '../model/media_info_state.dart';

/// Media details and the once-a-second statistics sampling.
class MediaInfoController extends ChangeNotifier {
  MediaInfoController({required this.backend});

  final PlayerBackend backend;

  MediaInfoState _state = const MediaInfoState();
  MediaInfoState get state => _state;
  bool _disposed = false;
  Timer? _statsTimer;

  void _set(MediaInfoState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  Future<void> load() async {
    if (!backend.supportsMediaInfo) return;
    try {
      final info = await backend.getMediaInfo();
      _set(MediaInfoState(info: info, stats: _state.stats));
    } catch (error) {
      debugPrint('Media info failed: $error');
    }
  }

  /// Samples statistics while [wanted] (a statistics view is shown).
  void updatePolling(bool wanted) {
    if (!backend.supportsMediaInfo || !wanted) {
      _statsTimer?.cancel();
      _statsTimer = null;
      return;
    }
    if (_statsTimer != null) return;
    Future<void> sample() async {
      try {
        final stats = await backend.getStats();
        _set(MediaInfoState(info: _state.info, stats: stats));
      } catch (_) {}
    }

    unawaited(sample());
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) => sample());
  }

  /// Forgets the previous media's details.
  void reset() => _set(const MediaInfoState());

  @override
  void dispose() {
    _disposed = true;
    _statsTimer?.cancel();
    super.dispose();
  }
}
