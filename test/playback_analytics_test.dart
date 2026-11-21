import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/analytics/playback_analytics.dart';
import 'package:openplayx_playback/playback.dart';

void main() {
  test('measures startup, playing, buffering and pause separately; ending emits once', () {
    var clock = Duration.zero;
    final events = <(String, Map<String, Object>)>[];
    final tracker = PlaybackAnalytics(
      clock: () => clock,
      emit: (e, p) => events.add((e, p)),
    );
    tracker.begin();
    clock = const Duration(seconds: 2);
    tracker.update(const PlayerSnapshot(status: PlaybackStatus.playing));
    expect(events.last.$2['startup_ms'], 2000);
    clock = const Duration(seconds: 12);
    tracker.update(
      const PlayerSnapshot(status: PlaybackStatus.playing, isBuffering: true),
    );
    clock = const Duration(seconds: 15);
    tracker.update(const PlayerSnapshot(status: PlaybackStatus.paused));
    clock = const Duration(seconds: 25);
    tracker.update(const PlayerSnapshot(status: PlaybackStatus.playing));
    clock = const Duration(seconds: 30);
    tracker.update(
      const PlayerSnapshot(
        status: PlaybackStatus.ended,
        position: Duration(seconds: 15),
        duration: Duration(seconds: 15),
      ),
    );
    tracker.finish();
    tracker.update(const PlayerSnapshot(status: PlaybackStatus.ended));
    final result = events.where((e) => e.$1 == 'playback_finished').single.$2;
    expect(result['playing_ms'], 15000);
    expect(result['buffering_ms'], 3000);
    expect(result['buffering_count'], 1);
    expect(result['completed'], true);
    expect(result['progress_percent'], 100);
  });
  test(
    'seek does not imply completion; switching media finalizes old attempt',
    () {
      var clock = Duration.zero;
      final events = <(String, Map<String, Object>)>[];
      final tracker = PlaybackAnalytics(
        clock: () => clock,
        emit: (e, p) => events.add((e, p)),
      );
      tracker.begin();
      tracker.update(const PlayerSnapshot(status: PlaybackStatus.playing));
      clock = const Duration(seconds: 1);
      tracker.update(
        const PlayerSnapshot(
          status: PlaybackStatus.paused,
          position: Duration(hours: 2),
          duration: Duration(hours: 2),
        ),
      );
      tracker.begin();
      final summaries = events
          .where((e) => e.$1 == 'playback_finished')
          .toList();
      expect(summaries.single.$2['playing_ms'], 1000);
      expect(summaries.single.$2['completed'], false);
      expect(
        events.first.$2['playback_id'],
        isNot(events.last.$2['playback_id']),
      );
      tracker.update(const PlayerSnapshot(status: PlaybackStatus.error));
      expect(events.where((e) => e.$1 == 'playback_failed').length, 1);
      expect(events.where((e) => e.$1 == 'playback_finished').length, 2);
    },
  );
}
