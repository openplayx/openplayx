import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:openplayx/data/analytics/analytics_service.dart';
import 'package:openplayx/data/configuration/configuration_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('configured build starts analytics without an enabled setting', (
    tester,
  ) async {
    expect(AnalyticsService.environment, 'validation');
    final db = await ConfigurationDatabase.open();
    final original = ConfigurationDatabase.readSetting(
      db,
      'analytics',
      'enabled',
    );
    // A previous version's disabled preference must not gate startup.
    ConfigurationDatabase.writeSetting(db, 'analytics', 'enabled', false);
    final analytics = AnalyticsService.instance;
    try {
      // Exercise SDK state persisted by a previous build too.
      final previousConfig = PostHogConfig(AnalyticsService.token)
        ..host = AnalyticsService.host
        ..captureApplicationLifecycleEvents = false
        ..sessionReplay = false
        ..surveys = false
        ..preloadFeatureFlags = false
        ..personProfiles = PostHogPersonProfiles.never;
      await Posthog().setup(previousConfig);
      await Posthog().optOut();
      await Posthog().close();
      await analytics.load();
      expect(analytics.enabled, isTrue);
      // Repeated initialization shares one future and does not emit a session twice.
      await analytics.load();
      await Posthog().flush();
      await Future<void>.delayed(const Duration(seconds: 3));
    } finally {
      await Posthog().close();
      ConfigurationDatabase.writeSetting(db, 'analytics', 'enabled', original);
      db.close();
    }
  });
}
