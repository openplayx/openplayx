/// Declarative, compiled-in fields. The host renders and validates the schema.
enum ConfigFieldType { text, directory, secret }

class ConfigField {
  const ConfigField(
    this.key,
    this.label, {
    this.type = ConfigFieldType.text,
    this.required = false,
    this.help,
  });
  final String key;
  final String label;
  final ConfigFieldType type;
  final bool required;
  final String? help;
}

class PluginConfigSchema {
  const PluginConfigSchema({required this.version, required this.fields});
  final int version;
  final List<ConfigField> fields;
}
