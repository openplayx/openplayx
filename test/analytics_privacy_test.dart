import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/analytics/analytics_service.dart';

void main() {
  test('bounded metrics survive sanitization while invalid values and identifiers do not', () {
    expect(
      AnalyticsService.sanitize({
        'duration_ms': 1234,
        'playing_ms': 42,
        'screen_name': 'MediaDetailPage',
        'playback_id': 'attempt-123',
        'completed': true,
        'timezone_offset_minutes': -660,
        'startup_ms': double.nan,
        'buffering_ms': double.infinity,
        'item_count': 999999999999,
        'filename': 'private.mp4',
        'email': 'private@example.com',
        r'$screen_name': '/Users/private/media',
      }),
      {
        'duration_ms': 1234,
        'playing_ms': 42,
        'screen_name': 'MediaDetailPage',
        'playback_id': 'attempt-123',
        'completed': true,
        'timezone_offset_minutes': -660,
      },
    );
  });
  test('private paths, credentials, conversations and forged enum values are dropped', () {
    final safe = AnalyticsService.sanitize({
      'source_type': 'smb',
      'success': true,
      'server': 'smb://private-host/films',
      'filename': 'Private Movie.mkv',
      'password': 'must-not-leave-device',
      'prompt': 'private conversation',
      'error_category': 'failed at /Users/example/private.mkv',
    });
    expect(safe, {'source_type': 'smb', 'success': true});
  });
  test('unconfigured debug builds do not initialize analytics', () async {
    expect(AnalyticsService.instance.configured, isFalse);
    await AnalyticsService.instance.load();
    expect(AnalyticsService.instance.enabled, isFalse);
    await AnalyticsService.instance.capture('playback_started');
    await AnalyticsService.instance.capture('unexpected_event', {
      'secret': 'private',
    });
    expect(AnalyticsService.instance.enabled, isFalse);
  });
}
