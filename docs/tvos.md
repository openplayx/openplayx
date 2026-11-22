# Apple TV (tvOS) — v0.0.4

The dedicated tvOS runner reuses the OpenPlayX Dart app. Minimum OS: **tvOS 17**,
ARM64. Flutter upstream does not support tvOS; this target uses FlutterTV CLI
1.12.2, commit `1540a52432331d9bf998a51f34eb2d006ef362f6`, Flutter 3.50.1,
Dart 3.14.0 and Xcode 27.2.

## Included functionality

- TVVLCKit 3.7.3 playback, full existing FFmpeg 7.1.1 codec set and sing-box
  1.12.12 remote-access core.
- Native Sentry Cocoa 9.32.0 and PostHog iOS SDK 3.98.2 adapters. Neither is
  disabled by build defines. Sentry maps tvOS to its Darwin/iOS native integration
  because its Dart platform enum has no tvOS value; Cocoa supplies tvOS contexts.
  PostHog events, identity/session and errors use its official tvOS SDK. Upstream
  iOS-only replay, surveys and push APIs are not advertised as tvOS features.
- Native ASWebAuthenticationSession nearby-device authentication, using the
  existing OAuth state/PKCE checks and publisher client configuration. Apple TV
  does not provide an embedded browser. Provider acceptance requires configured
  publisher client IDs and a nearby device; it is not verified by the smoke test.
- A remote-compatible native file/folder picker for real app-owned local files.
  tvOS does not expose iPhone's system document picker or unrestricted storage.
- Audio recording through record_ios 1.2.0's native AVAudioRecorder/AVAudioEngine
  implementation, with Apple's Continuity device picker before voice recording.
  Connect a compatible iPhone/iPad microphone. This does not access the Siri
  Remote's private Siri microphone stream. iPhone speaker-route/muted-interruption
  flags have no tvOS equivalents; TV audio output remains system-managed.
- BGTaskScheduler processing with an independent Flutter engine and metadata
  queue dispatcher. Foreground metadata continues immediately; unfinished work
  is scheduled on suspension. The OS controls execution and expiry. The simulator
  returns background scheduling unavailable, so OS-launched background execution
  remains a physical-device acceptance item.
- whisper.cpp 1.9.5 with Metal, Core ML and Accelerate compiled for tvOS. Device
  builds enable Metal. MTLSimDevice traps on Whisper weight buffer uploads, so
  simulator builds use Core ML/CPU instead. CUDA/Vulkan are not Apple TV backends.
- Offline multilingual tiny weights and its Core ML encoder, included as verified
  build-time resources. Fresh tvOS installations select tiny by default. The model
  store installs them into writable cache and restores them if tvOS purges it.
  Other catalogue models remain downloadable.

Physical Apple TV installation, OS-scheduled task execution, nearby-device OAuth,
Continuity microphone capture and physical remote interaction remain unverified.
The APIs and plugins are compiled and wired; this is not a claim of hardware tests.
Continuity input requires Apple TV 4K (2nd generation or later), tvOS 17+, and a
compatible iPhone/iPad with iOS/iPadOS 17+.

## Downloads and signing

GitHub Releases offers the normal `*-tvos-arm64-*.ipa` for user re-signing and
`*-tvos-appstore-arm64-*.ipa`, exported with a verified Apple Distribution
signature and App Store profile. The latter is for Apple distribution and cannot
be installed merely by tapping a download link. It is not an ad-hoc profile for
arbitrary devices, and an exported IPA alone is not a public TestFlight release.

The build first compiles an unsigned staging app, then signs during App Store
export. `codesign --verify --deep --strict` and the Apple Distribution authority
are checked on the actual exported IPA. No tester invitations or notifications
are sent by the signing script.

## Reproduce

Sibling FFmpeg, Whisper and SMB checkouts are required as described in README.
Use the pinned FlutterTV toolchain above, CocoaPods, CMake, pkg-config, Go, Python,
OpenSSL and Xcode with tvOS SDKs.

```sh
bash tool/prepare_tvos_models.sh
FLUTTER_TVOS_BIN=/path/to/flutter-tvos/bin/flutter-tvos \
OPX_TVOS_SIGNING_BUNDLE=/private/path/asc-api-bundle.zip \
bash tool/build_tvos.sh
```

Omit the credential variable to build only a re-signable IPA. Credentials are not
committed or embedded. Outputs go to `build/tvos-artifacts/`, outside FlutterTV's
asset staging tree. The script rejects an IPA with an invalid Payload layout,
missing native bridges or non-tvOS frameworks. Build source is `lib/main.dart`.

## Verification

`tool/tvos_smoke.dart` exercises SQLite/cache, VLC decode/pause/seek/resume,
FFmpeg probe/snapshot and remote-core lifecycle. `tool/tvos_plugins_smoke.dart`
checks native services and file-picker registration, authentication URL validation,
WAV encoder availability, offline model installation, enabled backend reporting,
real transcription and native Sentry/PostHog capture into a local HTTP collector.
It does not contact production telemetry or authorize a real cloud account.
Hardware-dependent checks are reported explicitly, not fabricated as passed.

```sh
flutter-tvos run -d <Apple-TV-simulator-id> -t tool/tvos_plugins_smoke.dart
```

Reports are written under `Library/Caches/OpenPlayX/`. tvOS may purge configuration,
indexes and generated artifacts in that directory; use server sources as the
recoverable source of media.

## Sources, licenses and models

Native adapters preserve upstream licenses in their package directories. Runtime
license copies are generated into the tvOS model resource bundle and sideload IPA.
SDK revisions are pinned in Package.swift/Package.resolved. Model weights are never
committed; `prepare_tvos_models.sh` verifies downloads before embedding them:

- ggml-tiny.bin (77,691,713 bytes): SHA-256
  `be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21`.
- ggml-tiny-encoder.mlmodelc.zip (15,037,446 bytes): SHA-256
  `c88cbd2648e1f5415092bcf5256add463a0f19943e6938f46e8d4ffdebd47739`.
- Model source: https://huggingface.co/ggerganov/whisper.cpp ; OpenAI Whisper weights
  retain their upstream MIT terms: https://github.com/openai/whisper .
- TVVLCKit source: https://code.videolan.org/videolan/VLCKit/-/tree/319ed2c0
  and https://code.videolan.org/videolan/vlc/-/tree/79128878 .
