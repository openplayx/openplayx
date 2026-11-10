import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'diagnostics_service.dart';

const _dsn = String.fromEnvironment('SENTRY_DSN');
const _environment = String.fromEnvironment(
  'SENTRY_ENVIRONMENT',
  defaultValue: kReleaseMode ? 'production' : 'development',
);
const _release = String.fromEnvironment('SENTRY_RELEASE');
const _dist = String.fromEnvironment('SENTRY_DIST');

/// A fresh event is built from an allowlist, rather than attempting to redact
/// arbitrary URLs, SQL, provider messages, scope data or attachment contents.
SentryEvent sanitizeDiagnosticEvent(SentryEvent event, DiagnosticRole role) {
  return SentryEvent(
    eventId: event.eventId,
    timestamp: event.timestamp,
    release: event.release,
    dist: event.dist,
    environment: event.environment,
    platform: event.platform,
    level: SentryLevel.error,
    tags: {
      'engine_role': role.name,
      if (DiagnosticFailure.values.any((f) => f.name == event.tags?['failure']))
        'failure': event.tags!['failure']!,
    },
    exceptions: [
      for (final exception in event.exceptions ?? <SentryException>[])
        SentryException(
          type:
              RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,79}$')
                  .hasMatch(exception.type ?? '')
              ? exception.type
              : 'UnexpectedError',
          value: '[redacted]',
          stackTrace: exception.stackTrace == null
              ? null
              : SentryStackTrace(
                  frames: [
                    for (final frame in exception.stackTrace!.frames)
                      if (RegExp(r'^(package:|dart:)[a-zA-Z0-9_./:-]+$')
                          .hasMatch(frame.absPath ?? frame.fileName ?? ''))
                        SentryStackFrame(
                          fileName: frame.absPath ?? frame.fileName,
                          lineNo: frame.lineNo,
                          colNo: frame.colNo,
                          inApp: frame.inApp,
                        ),
                  ],
                ),
        ),
    ],
  );
}

Future<void> reportDiagnostic(
  DiagnosticFailure failure,
  DiagnosticRole role,
  StackTrace stack,
) async {
  if (!Sentry.isEnabled || !await DiagnosticsService.enabled()) return;
  try {
    await Sentry.captureException(
      StateError(failure.name),
      stackTrace: stack,
      withScope: (scope) => scope.setTag('failure', failure.name),
    ).timeout(const Duration(seconds: 2));
  } catch (_) {
    /* Diagnostics must never break playback or task completion. */
  }
}

Future<void> runWithDiagnostics(
  DiagnosticRole role,
  Future<void> Function() start,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Sentry.isEnabled || _dsn.isEmpty || !await DiagnosticsService.enabled()) {
    await start();
    return;
  }
  // Native SDKs own process-wide state and disk caches. Until multi-engine
  // consent/cache handling is verified we deliberately use Dart capture only.
  try {
    await SentryFlutter.init((options) {
      options
        ..dsn = _dsn
        // Restore the SDK's Dart HTTP transport instead of native disk caching.
        ..transport = SentryOptions().transport
        ..enableScopeSync = false
        ..enablePrintBreadcrumbs = false
        ..sendClientReports = false
        ..environment = _environment
        ..release = _release.isEmpty ? null : _release
        ..dist = _dist.isEmpty ? null : _dist
        ..autoInitializeNativeSdk = false
        ..enableNativeCrashHandling = false
        ..enableAutoSessionTracking = false
        ..enableAutoNativeBreadcrumbs = false
        ..enableAppHangTracking = false
        ..enableAutoPerformanceTracing = false
        ..enableNativeTraceSync = false
        ..sendDefaultPii = false
        ..attachScreenshot = false
        ..attachViewHierarchy = false
        ..tracesSampleRate = 0
        ..maxBreadcrumbs = 0
        ..beforeBreadcrumb = ((_, _) => null)
        ..beforeSendLog = ((_, _) => null)
        ..beforeSendMetric = ((_, _) => null)
        ..beforeSend = (event, hint) async => await DiagnosticsService.enabled()
            ? sanitizeDiagnosticEvent(event, role)
            : null;
    });
  } catch (_) {
    debugPrint('Diagnostics unavailable; continuing startup.');
  }
  await start();
}
