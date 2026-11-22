import 'dart:io';

import 'package:sentry_flutter_tvos/sentry_flutter_tvos.dart';

import 'dart:async';

import '../analytics/analytics_service.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

enum DiagnosticRole { main, player, background }

// Sentry DSNs are public client keys; --dart-define=SENTRY_DSN=... overrides
// this default (pass an empty value to build without diagnostics).
const _dsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue: 'https://df1d46e6b16ecec16b8ae4144bdbbb08@o4509140630962176.ingest.us.sentry.io/4512412742385664',
);
const _environment = String.fromEnvironment(
  'SENTRY_ENVIRONMENT',
  defaultValue: kReleaseMode ? 'production' : 'development',
);
const _release = String.fromEnvironment('SENTRY_RELEASE');
const _dist = String.fromEnvironment('SENTRY_DIST');

Future<void> reportDiagnostic(
  Object error,
  DiagnosticRole role,
  StackTrace stack,
) async {
  if (!Sentry.isEnabled) return;
  try {
    await Sentry.captureException(
      error,
      stackTrace: stack,
      withScope: (scope) => scope.setTag('engine_role', role.name),
    ).timeout(const Duration(seconds: 2));
  } catch (_) {
    /* Diagnostics must never break playback or task completion. */
  }
}

Future<void> runWithDiagnostics(
  DiagnosticRole role,
  Future<void> Function() start, {
  String dsn = _dsn,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Sentry.isEnabled || dsn.isEmpty) {
    await start();
    return;
  }
  var started = false;
  try {
    await SentryFlutter.init(
      (options) {
        options
          ..beforeSend = (event, hint) {
            unawaited(
              AnalyticsService.instance.capture(r'$exception', {
                'error_type':
                    event.exceptions?.firstOrNull?.type ?? 'Exception',
                'engine_role': role.name,
              }),
            );
            return event;
          }
          ..dsn = dsn
          ..environment = _environment
          ..release = _release.isEmpty ? null : _release
          ..dist = _dist.isEmpty ? null : _dist;
        // Only the main engine owns the process-wide native SDK. Secondary
        // engines send Dart events directly without syncing native scope.
        if (role != DiagnosticRole.main) {
          options
            ..autoInitializeNativeSdk = false
            ..enableScopeSync = false
            ..transport = SentryOptions().transport;
        }
      },
      options: Platform.operatingSystem == 'tvos' ? tvosSentryOptions() : null,
      appRunner: () async {
        started = true;
        await start();
      },
    );
  } catch (_) {
    // Never restart an application whose own startup failed.
    if (started) rethrow;
    debugPrint('Diagnostics unavailable; continuing startup.');
    await start();
  }
}
