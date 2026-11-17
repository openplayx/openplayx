import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// How the video is placed in the player area (design §5.4).
enum VideoFitMode {
  /// Whole picture visible, letterboxed (VLC "best fit").
  fit,

  /// Fills the area; edges outside it are cropped.
  fill,

  /// One video pixel per logical pixel, centred.
  original,
}

/// Forced display aspect ratios, VLC's list. Null means the source ratio.
const videoAspectRatios = <double?>[
  null,
  16 / 9,
  4 / 3,
  1,
  16 / 10,
  2.21,
  2.35,
  2.39,
  5 / 4,
];

const videoAspectLabels = [
  null,
  '16:9',
  '4:3',
  '1:1',
  '16:10',
  '2.21:1',
  '2.35:1',
  '2.39:1',
  '5:4',
];

/// VLC zoom steps relative to the fitted size.
const videoZoomSteps = [0.25, 0.5, 1.0, 2.0];

@immutable
class VideoFrameSettings {
  const VideoFrameSettings({
    this.mode = VideoFitMode.fit,
    this.aspectIndex = 0,
    this.zoom = 1,
  });
  final VideoFitMode mode;

  /// Index into [videoAspectRatios].
  final int aspectIndex;

  /// Extra scale on top of [mode]: VLC zoom steps or a pinch value.
  final double zoom;

  double? get aspect => videoAspectRatios[aspectIndex];
  bool get isDefault =>
      mode == VideoFitMode.fit && aspectIndex == 0 && zoom == 1;

  VideoFrameSettings copyWith({
    VideoFitMode? mode,
    int? aspectIndex,
    double? zoom,
  }) => VideoFrameSettings(
    mode: mode ?? this.mode,
    aspectIndex: aspectIndex ?? this.aspectIndex,
    zoom: zoom ?? this.zoom,
  );

  @override
  bool operator ==(Object other) =>
      other is VideoFrameSettings &&
      other.mode == mode &&
      other.aspectIndex == aspectIndex &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(mode, aspectIndex, zoom);
}

/// Where the video surface goes: [size] is the box the native view fills
/// with the source aspect ratio (it letterboxes inside its box), and
/// [scaleX]/[scaleY] stretch that box to a forced display ratio.
@immutable
class VideoLayout {
  const VideoLayout(this.size, {this.scaleX = 1, this.scaleY = 1});
  final Size size;
  final double scaleX, scaleY;

  @override
  bool operator ==(Object other) =>
      other is VideoLayout &&
      other.size == size &&
      other.scaleX == scaleX &&
      other.scaleY == scaleY;

  @override
  int get hashCode => Object.hash(size, scaleX, scaleY);

  @override
  String toString() => 'VideoLayout($size, ×$scaleX, ×$scaleY)';
}

/// Computes the video box for [area]. Without a known video size the view
/// simply fills the area and letterboxes itself.
VideoLayout layoutVideo(Size area, Size? video, VideoFrameSettings settings) {
  if (video == null ||
      video.isEmpty ||
      area.isEmpty ||
      (settings.isDefault && settings.mode == VideoFitMode.fit)) {
    return VideoLayout(area);
  }
  final source = video.width / video.height;
  final display = settings.aspect ?? source;
  // Size the box at the display ratio first, then express it as a box with
  // the source ratio plus a horizontal stretch.
  Size shown;
  switch (settings.mode) {
    case VideoFitMode.fit:
      shown = _fitted(area, display, cover: false);
    case VideoFitMode.fill:
      shown = _fitted(area, display, cover: true);
    case VideoFitMode.original:
      shown = Size(video.height * display, video.height);
  }
  shown = shown * settings.zoom;
  final box = Size(shown.height * source, shown.height);
  return VideoLayout(box, scaleX: shown.width / box.width);
}

Size _fitted(Size area, double ratio, {required bool cover}) {
  final areaRatio = area.width / area.height;
  final widthBound = cover ? areaRatio < ratio : areaRatio > ratio;
  return widthBound
      ? Size(area.height * ratio, area.height)
      : Size(area.width, area.width / ratio);
}

/// Next VLC zoom step after [zoom] (wrapping), backwards with [reverse].
double nextZoomStep(double zoom, {bool reverse = false}) {
  var index = videoZoomSteps.indexWhere((step) => (step - zoom).abs() < 1e-6);
  if (index < 0) index = videoZoomSteps.indexOf(1);
  final length = videoZoomSteps.length;
  return videoZoomSteps[(index + (reverse ? length - 1 : 1)) % length];
}

/// Clamps a pinch zoom to a useful range.
double clampPinchZoom(double zoom) => math.min(4, math.max(0.25, zoom));
