import 'package:sentry_flutter/sentry_flutter.dart';
// Sentry 10.3 has no tvOS enum although its Cocoa SDK supports tvOS. Use the
// iOS-family native integration while native contexts retain the tvOS name.
// ignore: implementation_imports
import 'package:sentry/src/platform/platform.dart' as sentry;

class TVOSSentryPlatform extends sentry.Platform {
  const TVOSSentryPlatform();
  @override
  sentry.OperatingSystem get operatingSystem => sentry.OperatingSystem.ios;
}

SentryFlutterOptions tvosSentryOptions() =>
    SentryFlutterOptions(platform: const TVOSSentryPlatform());
