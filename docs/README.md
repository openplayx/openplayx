# Documentation

This index describes the current code organization. Individual implementation
notes include historical decisions and dated validation results; those are
not a fresh platform or deployment acceptance report.

## Current overview

- Navigation: Home/library, Sources, AI and Settings. AI manages models,
  external MCP services and internal capabilities.
- Configuration: `configuration.sqlite3` owns settings and credentials on
  their items (no separate OS keychain). `library.sqlite3` owns media,
  progress, conversations, jobs and artifacts. Development upgrades can
  rebuild old tables and lose data.
- Sources: local, SMB, WebDAV, FTP, SFTP, S3, Plex, Jellyfin, Emby and DLNA.
- AI: model calls and bounded tools; public web-page reading on the device,
  and a removable mcp-tavily web-search preset through the MCP client.
- Native media: libVLC playback, in-process FFmpeg processing and whisper.cpp
  recognition. Availability and device validation vary by platform.
- Remote access: app settings are stored through the configuration service;
  old notes mentioning app `remote_access.json` describe an earlier design.

The [English README](../README.md) and [中文 README](../README.zh-CN.md)
cover installation, build dependencies, current limits and privacy.

## Implementation notes

| Topic | Documents |
|---|---|
| Playback | [Native setup](implement/libvlc_basic_player.md), [controls](implement/basic_player_controls.md) |
| Library and metadata | [Library](implement/media_library.md), [storage layers](implement/library_storage_layers.md), [metadata](implement/media_metadata_scraping.md) |
| Sources | [Configuration](implement/source_instance_configuration.md), [SMB tuning](implement/smb_read_tuning.md), [progressive reads](implement/smb_progressive_reads.md) |
| AI | [Model integration](implement/langchain_dart_integration.md), [chat UI](implement/ai_chat_frontend.md), [page context](implement/page_context.md) |
| Remote access | [Core and transport](implement/remote_access_singbox_frp.md), [configuration](implement/remote_access_configuration.md) |
| UI and setup | [Design system](implement/frontend_design_system.md), [initial setup history](implement/flutter_project_initialization.md) |
| Development configuration | [Debug seed](debug_seed.md) |
| Diagnostics | [Sentry](../SENTRY.md) |

## Tests and contribution

[Unit/widget tests](../test/README.md),
[native integration tests](../integration_test/README.md),
[test services](../tool/source_services/README.md),
[contributing](../CONTRIBUTING.md) and [security](../SECURITY.md).

Private architecture and deployment repositories are maintained separately.
Public documentation must be usable without those repositories and must not
copy their credentials or internal operational details.
