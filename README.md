# OpenPlayX

English | [简体中文](README.zh-CN.md)

A Flutter and libVLC media player for local files, network storage and media
servers, with a local media library and an optional AI assistant.

The project is under active development. macOS is the main development
platform. Android and Apple Silicon macOS installers are published on
[GitHub Releases](https://github.com/openplayx/openplayx/releases); platform
projects and shared Dart code do not imply full device coverage.

## Features

| Area | Current implementation |
|---|---|
| Playback | Local and remote media, seeking, speed, volume, audio tracks, external subtitles and keyboard controls |
| Sources | Local folders, SMB, WebDAV, FTP, SFTP, S3, Plex, Jellyfin, Emby and DLNA adapters; capabilities vary by source |
| Library | Scanning, search, filters, favorites, watch progress, seasons/episodes, extras and resource versions |
| Metadata | Filename parsing, NFO/artwork import, TMDB matching, review, field locks and artwork selection |
| AI | Configurable OpenAI-compatible models, streaming conversations, bounded tools and confirmation for actions |
| External tools | User-configured MCP services, a removable web-search preset and built-in public-page reading |
| Media processing | In-process FFmpeg and whisper.cpp integration, subtitle generation and local artifacts; availability depends on platform/build |
| Remote access | Embedded sing-box with optional [Home](https://github.com/openplayx/openplayx-home) and [Relay](https://github.com/openplayx/openplayx-relay) services |
| Interface | Home/library, Sources, AI and Settings; adaptive navigation, shadcn_ui, Lucide and localized strings |

The app runs locally without an OpenPlayX server. Models, online metadata,
web search and remote services are optional network capabilities. Complete
cross-device sync, live TV/IPTV/EPG and TV remote interfaces are not provided.
The Flutter Web player is not supported; [openplayx.com](https://openplayx.com)
is the separate project website.

## Download

Use the assets and installation notes on the
[release page](https://github.com/openplayx/openplayx/releases).
Only install builds for the listed platform and architecture. Windows,
Linux and iOS source trees are not a promise of a ready-to-install release.

## Build from source

Requirements: Flutter with Dart satisfying `^3.13.7`, platform development
tools (Xcode and CocoaPods for macOS/iOS), and Go/C toolchains for native
components. See [native playback notes](docs/implement/libvlc_basic_player.md)
and [remote access notes](docs/implement/remote_access_singbox_frp.md).

The app currently needs sibling checkouts named `ffmpeg-package`,
`package-whisper` and `smb_connect`. `ffmpeg-package` and the SMB fork are
private dependencies, so cloning this public repository alone is insufficient
to reproduce the current build. Contributors with access can prepare them:

```sh
git clone https://github.com/openplayx/openplayx.git
git clone https://github.com/openplayx/package-whisper.git
git clone git@github.com:openplayx/ffmpeg-package.git
git clone git@github.com:openplayx/smb_connect.git
cd openplayx
flutter doctor
flutter pub get
flutter run -d macos
```

`pubspec.yaml` is the dependency source of truth, including the local SMB
override. Native libraries and platform toolchains must also be available;
VLC desktop installation is not required. Source access and build access
are separate from installer availability.

## First use

1. Open a file, or add a connection under Sources and browse it directly.
2. Create a library and scan an authorized folder to organize its media.
3. Configure metadata lookup if wanted; review ambiguous matches.
4. Under AI, configure a model and its credentials, test the connection and
   review data-sharing consent. External MCP services are managed there too.
5. Use Settings for appearance, language, recognition, remote access and
   optional diagnostics.

Scanning does not download videos. Server-side download tools are separate
services, and actions require confirmation. Web search uses the bundled
mcp-tavily connection; removing it keeps it removed. Public-page reading
runs on the device and refuses local/private addresses.

## Data and privacy

- `configuration.sqlite3` stores settings, source credentials, API keys and
  service tokens on their configuration items. It currently uses neither a
  separate OS keychain nor application-level database encryption. Protect
  the app data directory and any backups.
- `library.sqlite3` stores media records, progress, conversations, jobs and
  artifacts. Development schema upgrades can recreate older tables and
  discard their data; lossless migration is not guaranteed yet.
- Model requests can include conversation and authorized tool context.
  Web searches go to the configured search service; page reading contacts
  the requested public site. Local playback does not require an AI model.
- Diagnostics are opt-in; see [SENTRY.md](SENTRY.md) for collection and build
  settings. Never publish databases, debug seeds or logs containing secrets.

See [security reporting](SECURITY.md) and
[current implementation notes](docs/README.md).

## Development

```sh
flutter analyze
flutter test
```

Tests requiring native players, models, real services or devices have
additional requirements. Read [unit/widget tests](test/README.md),
[integration tests](integration_test/README.md) and
[test service setup](tool/source_services/README.md). Live checks are opt-in;
passing mocked tests does not verify every device or media format.

The UI and application wiring live in `lib/app`, feature pages in
`lib/features`, services in `lib/services`, source/storage implementations
in `lib/data`, and the playback bridge in `packages/playback`.

## Documentation and contributing

Start at the [documentation index](docs/README.md). The repository contains
implementation notes and dated validation records. Historical notes can
describe an earlier design; check the code and current overview first.
Internal deployment documents are maintained separately and are not required
to use the published installers.

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).
Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## License and acknowledgements

This repository currently has no root project license. Public source access
does not grant a project-wide open-source license; dependency licenses do
not define the app's license. No new license is granted by this README.

Thanks to Flutter, VideoLAN/libVLC, vlc_player, shadcn_ui, Lucide,
whisper.cpp, FFmpeg and the other dependencies. Their own licenses and
redistribution obligations continue to apply; see the relevant packages
and [`native/remote_access/LICENSE`](native/remote_access/LICENSE).
