/// Measures input bytes per wall-clock second, in decimal MB (1,000,000 bytes).
/// A fresh or reset counter needs a baseline before a rate can be reported.
class ReadSpeedMeter {
  int? _bytes;
  Duration? _time;

  double? sample(int bytes, Duration time) {
    final previousBytes = _bytes;
    final previousTime = _time;
    if (bytes < 0) {
      reset();
      return null;
    }
    if (previousTime != null && time <= previousTime) return null;
    _bytes = bytes;
    _time = time;
    if (previousBytes == null ||
        previousTime == null ||
        bytes < previousBytes) {
      return null;
    }
    // Microseconds per second and bytes per MB both equal 1,000,000.
    return (bytes - previousBytes) / (time - previousTime).inMicroseconds;
  }

  void reset() {
    _bytes = null;
    _time = null;
  }
}
