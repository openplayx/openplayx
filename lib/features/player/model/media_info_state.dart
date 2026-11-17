import 'package:flutter/foundation.dart';
import 'package:openplayx_playback/playback.dart';

/// Details and live statistics of the current media.
@immutable
class MediaInfoState {
  const MediaInfoState({this.info, this.stats});
  final PlayerMediaInfo? info;

  /// Last statistics sample, refreshed while a statistics view is shown.
  final PlayerStats? stats;
}
