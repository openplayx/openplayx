# Diagnostics

Dependencies are pinned to sentry_flutter 10.3.0 and sentry_dart_plugin 3.4.0.

## Build and enable

The project DSN (US region) is built in as the default in
`lib/data/diagnostics/diagnostics_bootstrap.dart`. Override it with
`--dart-define=SENTRY_DSN=...`, or pass `--dart-define=SENTRY_DSN=` to build
without diagnostics. Build with values matching the actual artifact, for example:

```sh
flutter build macos --release \
  --dart-define=SENTRY_DSN=https://PUBLIC_KEY@HOST/PROJECT_ID \
  --dart-define=SENTRY_ENVIRONMENT=staging \
  --dart-define=SENTRY_RELEASE=openplayx@0.0.1+1 \
  --dart-define=SENTRY_DIST=macos-arm64-1 \
  --split-debug-info=build/symbols
```

Error reporting is enabled whenever a DSN is configured. There is no runtime
preference, configuration database lookup or Settings switch. Old diagnostic
settings are unused. Missing/invalid SDK configuration or initialization failure
must not prevent application startup.

## SDK configuration and reports

The integration follows the [Sentry Flutter basic setup](https://pub.dev/packages/sentry_flutter).
It uses `SentryFlutter.init` with `appRunner`, DSN, environment
and optional release/dist overrides. Other features use SDK defaults. The main
engine initializes the native SDK. Player and background engines skip native
initialization and scope synchronization and use the Dart HTTP transport, so
they do not reinitialize process-wide native state.

There are no application-level event filters or redaction hooks. Caught playback
command and metadata batch failures send the original exception and stack via
`Sentry.captureException`, tagged with the engine role. Uncaught errors are
handled by SDK integrations. SDK defaults (including default PII behavior) and
Sentry project-side processing still apply; raw error messages, paths and
breadcrumb data are no longer removed by an application allowlist.

## Symbols

Run `dart run sentry_dart_plugin` only after the exact release build, with
SENTRY_AUTH_TOKEN, SENTRY_ORG, SENTRY_PROJECT, SENTRY_RELEASE and SENTRY_DIST
provided securely to that process. Add `--dart-symbol-map-path=build/symbols`
for split debug output. Source and source-map upload are disabled by default.
Never pass AUTH_TOKEN as a dart-define. sentry.properties is ignored.
Retain the original artifact, debug files and architecture together. The plugin
does not guarantee that prebuilt libVLC symbols are available or match.

## Verification and remaining acceptance

Run automated tests with `--dart-define=SENTRY_DSN=` to avoid live reporting.
Capture tests use a synthetic DSN and a no-op transport to verify original
exception messages, stack locations and engine tags without network requests.

Live acceptance remains: inspect received events from main/player/background,
check native capture and duplicate reports across engines, offline/restart
behavior, release symbol readability and overhead. Native/libVLC symbol coverage
must be checked on actual builds and devices.
