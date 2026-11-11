# Optional diagnostics

Dependencies are pinned to sentry_flutter 10.3.0 and sentry_dart_plugin 3.4.0.

## Build and enable

The project DSN (US region) is built in as the default in
`lib/app/diagnostics/diagnostics_bootstrap.dart`. Override it with
`--dart-define=SENTRY_DSN=...`, or pass `--dart-define=SENTRY_DSN=` to build
without diagnostics. Build with values matching the actual artifact, for example:

```sh
flutter build macos --release \
  --dart-define=SENTRY_DSN=https://PUBLIC_KEY@HOST/PROJECT_ID \
  --dart-define=SENTRY_ENVIRONMENT=staging \
  --dart-define=SENTRY_RELEASE=openplayx@1.0.0+1 \
  --dart-define=SENTRY_DIST=macos-arm64-1 \
  --split-debug-info=build/symbols
```

Users must separately enable Send diagnostics in Settings and restart. Default
is off. Missing/invalid configuration or SDK initialization failure must not
prevent application startup. Do not use production for acceptance tests.

Disable takes effect on the next event consent check in every engine. Requests
already in flight cannot be recalled. Preferences use SharedPreferencesAsync
rather than an engine-local cached snapshot. Enabling an existing main/player
engine requires restart; a fresh background engine reads the current preference.

## Current collection boundary

Main and player entries initialize separate Dart clients; background tasks do
likewise. Native initialization, scope synchronization, native crash handling,
sessions, performance tracing, screenshots, view trees, breadcrumbs, logs,
metrics and replay are not enabled. The transport explicitly uses Dart HTTP
rather than Sentry Flutter's default native filesystem transport. There is no
durable diagnostic queue or native replay-on-restart in this implementation.
Failed requests are dropped rather than retried by a business queue.

beforeSend reconstructs an event using an allowlist: release/dist/environment,
platform, engine role, fixed failure codes, exception type and package/Dart
stack locations. Raw exception messages, users, contexts, HTTP requests, local
paths, frame variables, arbitrary tags and breadcrumbs are discarded. This
intentionally sacrifices some debugging detail. Runtime engine roles are fixed;
no window request, media URI, provider response or AI content is attached.

Playback command failures and metadata batch failures use fixed-code reports.
The SDK handles uncaught Dart/Flutter exceptions. Expected cancellation and
network/business outcomes elsewhere are not automatically promoted to errors.
Performance spans remain disabled in this first phase.

## Symbols

Run `dart run sentry_dart_plugin` only after the exact release build, with
SENTRY_AUTH_TOKEN, SENTRY_ORG, SENTRY_PROJECT, SENTRY_RELEASE and SENTRY_DIST
provided securely to that process. Add `--dart-symbol-map-path=build/symbols`
for split debug output. Source and source-map upload are disabled by default.
Never pass AUTH_TOKEN as a dart-define. sentry.properties is ignored.
Retain the original artifact, debug files and architecture together. The plugin
does not guarantee that prebuilt libVLC symbols are available or match.

## Verification and remaining acceptance

Automated tests exercise the allowlist with private URLs, credentials, paths,
chat-like values and stack variables. No DSN is configured in tests.

On 2026-11-11 the Apple Sentry plugin compiled via SPM alongside CocoaPods, but
full debug packaging was blocked by existing dartssh2 2.14.0 nullability and an
unhandled SourceKind.webdav switch in source_instance_form.dart.

Still required with a test DSN: inspect actual outgoing envelopes, verify one
event per exception for main/player/background, consent-off across engines,
offline/reconnect/restart behavior, release symbol readability and overhead.
Native/libVLC crashes are **not covered**. Enabling native capture requires a
separate verified process owner, shared consent and cache-purge strategy,
server-side scrubbing and detached-device native crash/symbol acceptance.
Do not advertise native crash or all-platform coverage before these pass.
