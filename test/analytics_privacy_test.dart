import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/analytics/analytics_service.dart';

void main() {
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
