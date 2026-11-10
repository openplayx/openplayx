import 'package:openplayx/data/sources/source_config.dart';

// Connections to the disposable services in tool/source_services/compose.yaml,
// shared by probe.dart and integration_test/sources_test.dart.

/// Connection to the compose.yaml service for [kind] on [host].
SourceConfig sourceServiceConfig(
  SourceKind kind,
  String host,
  Map<String, dynamic> defines,
) => SourceConfig(
  id: 'probe-${kind.name}',
  kind: kind,
  name: kind.label,
  address: switch (kind) {
    SourceKind.local => '/',
    SourceKind.smb => 'smb://$host/media',
    SourceKind.webdav => 'http://$host:18080/media',
    SourceKind.ftp => 'ftp://$host:2121/media',
    SourceKind.sftp => 'sftp://$host:2222/media',
    SourceKind.s3 => 'http://$host:19000/media',
    SourceKind.plex => 'http://$host:13240',
    SourceKind.jellyfin => 'http://$host:18096',
    SourceKind.emby => 'http://$host:18097',
    SourceKind.dlna => 'http://$host:8200/rootDesc.xml',
  },
  username: kind == SourceKind.dlna || kind == SourceKind.plex
      ? ''
      : 'openplayx',
  userId: switch (kind) {
    SourceKind.jellyfin => defines['JELLYFIN_USER_ID'] as String? ?? '',
    SourceKind.emby => defines['EMBY_USER_ID'] as String? ?? '',
    _ => '',
  },
);

String sourceServiceSecret(SourceKind kind, Map<String, dynamic> defines) =>
    switch (kind) {
      SourceKind.plex => 'test-token',
      SourceKind.jellyfin => defines['JELLYFIN_TOKEN'] as String? ?? '',
      SourceKind.emby => defines['EMBY_TOKEN'] as String? ?? '',
      SourceKind.local || SourceKind.dlna => '',
      _ => 'test-only-password',
    };
