import '../../core/capabilities/config_schema.dart';
import '../../core/capabilities/source_capability.dart';
import 'source_config.dart';
import '../../l10n/l10n.dart';

class SourceSchemas {
  static PluginManifest forKind(SourceKind kind) => PluginManifest(
    'source.${kind.name}',
    kind.label,
    browseExperience: kind.files ? 'files' : 'library',
    capabilities: [
      'source.browse',
      'source.resolve',
      if (kind != SourceKind.dlna) 'source.attachments',
      if (kind == SourceKind.smb) 'source.write',
      if (kind.mediaBrowser || kind == SourceKind.plex) ...[
        'metadata.lookup',
        'search.media',
      ],
    ],
    configSchema: PluginConfigSchema(
      version: 2,
      fields: switch (kind) {
        SourceKind.onedrive || SourceKind.dropbox => [],
        SourceKind.local => [
          ConfigField(
            'address',
            appStrings.srcFieldFolder,
            type: ConfigFieldType.directory,
            required: true,
          ),
        ],
        SourceKind.smb => [
          ConfigField('address', appStrings.address, required: true),
          ConfigField('username', appStrings.username),
          ConfigField(
            'secret',
            appStrings.password,
            type: ConfigFieldType.secret,
          ),
          ConfigField('domain', appStrings.srcFieldWorkgroup),
        ],
        SourceKind.webdav || SourceKind.ftp => [
          ConfigField('address', appStrings.address, required: true),
          ConfigField('username', appStrings.username),
          ConfigField(
            'secret',
            appStrings.password,
            type: ConfigFieldType.secret,
          ),
        ],
        SourceKind.sftp => [
          ConfigField('address', appStrings.address, required: true),
          ConfigField('username', appStrings.username, required: true),
          ConfigField(
            'secret',
            appStrings.password,
            type: ConfigFieldType.secret,
          ),
        ],
        SourceKind.s3 => [
          ConfigField('address', appStrings.serverAddress, required: true),
          ConfigField('username', 'Access Key ID'),
          ConfigField(
            'secret',
            'Secret Access Key',
            type: ConfigFieldType.secret,
          ),
          ConfigField('domain', appStrings.srcFieldRegion),
        ],
        // Plex uses the account authorization flow, rather than a token form.
        SourceKind.plex => [
          ConfigField('address', appStrings.server, required: true),
        ],
        SourceKind.jellyfin || SourceKind.emby => [
          ConfigField('address', appStrings.address, required: true),
          ConfigField('username', appStrings.username),
        ],
        SourceKind.dlna => [
          ConfigField('address', appStrings.dlnaAddress, required: true),
        ],
      },
    ),
  );
  static void validate(SourceConfig config) {
    config.validate();
    final values = config.toJson();
    for (final field in forKind(config.kind).configSchema!.fields) {
      if (field.required &&
          field.type != ConfigFieldType.secret &&
          '${values[field.key] ?? ''}'.trim().isEmpty) {
        throw FormatException(appStrings.srcFieldRequired(field.label));
      }
    }
  }
}
