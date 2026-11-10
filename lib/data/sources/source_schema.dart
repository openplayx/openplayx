import '../../core/plugins/config_schema.dart';
import '../../core/plugins/source_capability.dart';
import 'source_config.dart';

class SourceSchemas {
  static PluginManifest forKind(SourceKind kind) => PluginManifest(
    'source.${kind.name}',
    kind.label,
    browseExperience: kind == SourceKind.local || kind == SourceKind.smb
        ? 'files'
        : 'library',
    capabilities: [
      'source.browse',
      'source.resolve',
      'source.attachments',
      if (kind == SourceKind.jellyfin || kind == SourceKind.plex) ...[
        'metadata.lookup',
        'search.media',
      ],
    ],
    configSchema: PluginConfigSchema(
      version: 2,
      fields: switch (kind) {
        SourceKind.local => const [
          ConfigField(
            'address',
            '文件夹',
            type: ConfigFieldType.directory,
            required: true,
          ),
        ],
        SourceKind.smb => const [
          ConfigField('address', '地址', required: true),
          ConfigField('username', '用户名'),
          ConfigField('secret', '密码', type: ConfigFieldType.secret),
          ConfigField('domain', '工作组（可选）'),
        ],
        // Plex uses the account authorization flow, rather than a token form.
        SourceKind.plex => const [
          ConfigField('address', '服务器', required: true),
        ],
        SourceKind.jellyfin => const [
          ConfigField('address', '地址', required: true),
          ConfigField('username', '用户名'),
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
        throw FormatException('请填写${field.label}。');
      }
    }
  }
}
