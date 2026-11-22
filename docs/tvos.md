# Apple TV (tvOS), experimental — v0.0.4

The Apple TV build reuses the OpenPlayX Dart application with a dedicated
`tvos/` Xcode runner and a TVVLCKit implementation of the existing VLC channel
contract. It requires tvOS 15 or later, arm64. Flutter upstream does not support
tvOS; this target uses [flutter-tvos](https://github.com/fluttertv/flutter-tvos).

## Install

Download the `*-tvos-arm64-*.ipa` asset from v0.0.4 on GitHub Releases.
It is **unsigned**: re-sign it with your own Apple developer certificate and
a provisioning profile covering your Apple TV before sideloading. It is not
an App Store or TestFlight download and cannot be installed by opening a web
link on Apple TV. A macOS ZIP, iOS IPA or Android TV APK cannot replace it.

Hardware installation and Siri Remote interaction have not been verified.
This release is experimental; do not treat simulator coverage as device coverage.

## Build

Use Xcode with the tvOS SDK, CocoaPods, and the sibling dependencies described
in the main README. The verified toolchain is flutter-tvos commit
`1540a52432331d9bf998a51f34eb2d006ef362f6` (CLI 1.12.2), Flutter 3.50.1,
Dart 3.14.0, Xcode 27.2, TVVLCKit 3.7.3, FFmpeg 7.1.1, whisper.cpp 1.9.5 and sing-box 1.12.12. tvOS companion plugins are pinned in
`pubspec.yaml` and `pubspec.lock`. The native package source revisions are
FFmpeg package `8d298bf` and Whisper package `0ab95a6`; use these companion
revisions when reproducing this Apple TV build.

```sh
git clone https://github.com/fluttertv/flutter-tvos.git /tmp/flutter-tvos
git -C /tmp/flutter-tvos checkout 1540a52432331d9bf998a51f34eb2d006ef362f6
/tmp/flutter-tvos/bin/flutter-tvos precache
FLUTTER_TVOS_BIN=/tmp/flutter-tvos/bin/flutter-tvos bash tool/build_tvos.sh
```

The script builds the **main application** in release mode and creates an IPA
under `build/tvos/dist/`, plus a SHA-256 checksum. It does not upload anything.
Analytics and Sentry native integrations are disabled in this build because
their tvOS plugins have not been ported. The system SQLite dylib is loaded
explicitly: the tvOS embedder does not generate Dart native-asset mappings.

The FFmpeg and Whisper `tvos/` podspecs build the same pinned sources and codec
recipes used by other platforms, with separate `tvos-arm64` and
`tvos-sim-arm64` outputs. iOS static archives are never linked into tvOS.
The remote core is built as a Go `ios/arm64` C archive with the actual tvOS
SDK and target triple, as supported by Go's tvOS linker test.

The tvOS runner uses the existing `com.openplayx.app` bundle ID. Signing for a
store release must configure the matching Apple developer team and tvOS profile.

## Storage and capability limits

- tvOS writes configuration, library indexes and generated files under
  `Library/Caches/OpenPlayX`. The OS may purge these files. Reconfigure sources
  and rebuild indexes if this happens; this is not durable library storage.
- VLC playback and the shared source adapters are present. The simulator
  smoke check covers SQLite, cache writes, MP4 decoding, pause, seeking and
  resuming. It does not verify all server protocols or media formats.
- FFmpeg (with the existing x264/x265/AV1/VP8/VP9/MP3/Opus codec set),
  whisper.cpp CPU recognition, and the sing-box transport core are included as
  native tvOS libraries. Model weights use the existing model catalogue and
  download flow; they are not embedded in the IPA.
- Local file selection, browser OAuth, microphone recording and background-task
  plugins have not been ported. Use network sources with directly configured
  credentials. These OS/plugin limitations do not remove FFmpeg media processing,
  speech-to-text from media files, or the remote-access core.
- The whole UI consumes TV overscan margins once so sidebar controls retain
  their width. Existing directional focus and select-to-Enter handling are
  reused; physical remote acceptance is still pending.

## Native smoke check

```sh
flutter-tvos run -d <Apple-TV-simulator-id> -t tool/tvos_smoke.dart
```

The test creates isolated probe databases and copies bundled test video/speech into
the app cache. Read `Library/Caches/OpenPlayX/tvos-smoke.json` in the simulator
container. A passing result has `status: passed`, with `sqlite`, `storage`,
`decode`, `pause`, `seek_resume`, `ffmpeg_probe_snapshot`,
`whisper_transcribe`, and `remote_start_stop` all `passed`. Seed the pinned
`ggml-tiny.bin` model in the same cache directory before running this check;
its expected SHA-256 is
`be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21`. The shipped IPA uses
`lib/main.dart`, never this test entry point.

## Third-party sources

The adapter in `packages/vlc_player_tvos` is adapted from vlc_player 2.1.2,
MIT, Copyright (c) 2026 lingjhf; its license is preserved there. TVVLCKit 3.7.3
is obtained from the checksummed CocoaPods spec. Source:
https://code.videolan.org/videolan/VLCKit/-/tree/319ed2c0 and
https://code.videolan.org/videolan/vlc/-/tree/79128878 .
The FlutterTV CLI, engine patches and plugins retain their upstream licenses:
https://github.com/fluttertv/flutter-tvos and https://github.com/fluttertv/plugins.
