# Third-party notices

This source-level inventory identifies major components of OpenPlayX. It is
not a complete bill of materials for every platform binary. Dependencies
retain their original notices. Original OpenPlayX application code and
documentation use MIT; that grant does not relicense third-party components.

| Component | Source / version authority | License and notices |
|---|---|---|
| Flutter / Dart | Flutter SDK used for the build | BSD-style SDK notices; Dart package snapshot below |
| vlc_player | package-libvlc companion `pubspec.yaml` (pinned 2.1.2) and `pubspec.lock` | MIT; original copyright retained in the Dart package snapshot |
| libVLC / VLCKit / MobileVLCKit | Apple Pod locks currently pin VLCKit 3.7.3 | Upstream LGPL terms and bundled component notices; [VideoLAN licensing](https://www.videolan.org/legal.html) and the actual SDK's COPYING/acknowledgements govern; [macOS snapshot](LICENSES/MACOS_PODS.txt), [iOS snapshot](LICENSES/IOS_PODS.txt) |
| sing-box | `native/remote_access/go.mod`, v1.12.12 | GPL-3.0-or-later with upstream naming/association restriction; [preserved notice](LICENSES/sing-box.txt), [GPL text](LICENSES/GPL-3.0.txt), [upstream](https://github.com/SagerNet/sing-box/tree/v1.12.12) |
| FFmpeg | Companion build pins 7.1.1 | LGPL-2.1-or-later for the configured LGPL-only build; [license](LICENSES/LGPL-2.1.txt), [source](https://ffmpeg.org/releases/ffmpeg-7.1.1.tar.xz), [legal notes](https://ffmpeg.org/legal.html) |
| whisper.cpp / ggml | package-whisper build pins whisper.cpp 1.9.5 | [Preserved MIT notice](LICENSES/whisper.cpp.txt); model weights have separate terms |
| package-whisper | Companion checkout used for the build | MIT; original wrapper notice in Dart package snapshot |
| SMB adapter | smb_connect companion / pinned fork | Apache-2.0; preserved in Dart package snapshot |
| shadcn_ui / lucide_icons_flutter | `pubspec.lock` | Package MIT notices in snapshot; retain notices for any upstream artwork included in the build |
| Other Dart packages | `pubspec.lock` and resolved package configuration | [Resolved package license snapshot](LICENSES/DART_PACKAGES.txt), including development tools |
| Go dependencies | `native/remote_access/go.mod` and `go.sum` | Preserve licenses from every module used in the release build, including transitive modules |
| Media-server branding | `assets/branding/README.md` | Existing source, attribution and trademark notes remain applicable |

The private FFmpeg bridge repository has its own licensing status. The app's
root license does not grant rights to separately maintained source. Access to
a dependency is not permission to redistribute it, and a public app checkout
still does not contain all build inputs.

## Maintaining notices

After `flutter pub get`, run:

```sh
python3 tool/update_license_notices.py
```

The script copies available LICENSE/COPYING files from the resolved package
roots, includes package versions, avoids recording local paths and reports
packages without notices. It includes development dependencies and is not a
claim that every listed package ships in an installer. Review missing entries
and native dependencies separately. Keep copied texts verbatim.

## Binary releases

The original application code uses MIT. Builds that link sing-box still
need to comply with its GPL-3.0-or-later terms, including the applicable
terms for the combined work. The root MIT license is not a claim that such
binaries are distributable under MIT alone. Upstream GPL text and notices
are retained in `LICENSES/` and `native/remote_access/LICENSE`.

For each actual release, retain the exact source revisions, dependency locks,
patches, build scripts and native build configuration. Provide corresponding
source for the GPL work and required library sources/materials under their
licenses, including companion code needed to build it. Private dependency
access must not prevent recipients from receiving required corresponding
source. Do not describe a source link to only this repository as a complete
source package when companion inputs are absent.

Include the relevant license texts and native SDK notices with installers.
For the LGPL-only FFmpeg build, retain the exact source and BUILDINFO/configure
line and satisfy the applicable relinking/source requirements for the actual
linkage. Verify the real configuration: enabling GPL or nonfree components
changes the distribution analysis. The release's license obligations depend
on what was built, not only on this table.

This documentation update does not change or certify existing installers,
model weights, remote-service data terms or any store's distribution terms.

## Apple TV experimental build

The tvOS build uses TVVLCKit 3.7.3 (LGPL-2.1-or-later), the MIT vlc_player adapter and the FlutterTV toolchain/plugins. It also bundles the pinned GPL FFmpeg codec build, MIT whisper.cpp CPU engine and GPL sing-box core, rebuilt for tvOS. Their existing notices and license obligations continue to apply. Exact toolchain revisions, source links and build steps are recorded in [docs/tvos.md](docs/tvos.md); the adapted VLC code preserves its MIT license in `packages/vlc_player_tvos/LICENSE`.

The extended tvOS build also includes Sentry Cocoa/Flutter, PostHog native/Flutter, record_ios-derived code, and verified OpenAI Whisper tiny/Core ML model resources. Their licenses are retained in adapter directories and generated runtime resources; see docs/tvos.md for versions and checksums.
