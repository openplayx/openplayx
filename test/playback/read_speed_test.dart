import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx_playback/read_speed.dart';

void main() {
  test('uses real sampling time and decimal MB rather than video bitrate', () {
    final meter = ReadSpeedMeter();
    expect(meter.sample(500000, Duration.zero), isNull);
    expect(meter.sample(3500000, const Duration(milliseconds: 1500)), 2);
    expect(meter.sample(3500000, const Duration(milliseconds: 2500)), 0);
  });

  test('new sessions and reset counters require a new baseline', () {
    final meter = ReadSpeedMeter();
    meter.sample(5000000, Duration.zero);
    expect(meter.sample(100, const Duration(seconds: 1)), isNull);
    expect(meter.sample(1000100, const Duration(seconds: 2)), 1);
    meter.reset();
    expect(meter.sample(100, const Duration(seconds: 3)), isNull);
    expect(meter.sample(-1, const Duration(seconds: 4)), isNull);
    expect(meter.sample(100, const Duration(seconds: 5)), isNull);
  });

  test(
    'duplicate timestamps cannot produce infinity or corrupt the baseline',
    () {
      final meter = ReadSpeedMeter();
      meter.sample(0, Duration.zero);
      expect(meter.sample(500, Duration.zero), isNull);
      expect(meter.sample(1000000, const Duration(seconds: 1)), 1);
    },
  );
}
