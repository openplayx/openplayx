import 'package:sqlite3/sqlite3.dart';

import '../../data/configuration/configuration_database.dart';
import '../../data/configuration/source_secure_store.dart';
import '../conversation/assistant_store.dart';

class VoiceConfig {
  const VoiceConfig({
    this.usePlatform = false,
    this.endpoint = 'https://api.openai.com/v1',
    this.model = 'whisper-1',
  });
  static const platformEndpoint = 'https://api.openplayx.com/v1';
  static const platformModel = 'whisper-1';
  final bool usePlatform;
  final String endpoint, model;
  String get effectiveEndpoint => usePlatform ? platformEndpoint : endpoint;
  String get effectiveModel => usePlatform ? platformModel : model;

  static String normalizeEndpoint(String value) => value
      .trim()
      .replaceFirst(RegExp(r'/+$'), '')
      .replaceFirst(RegExp(r'/audio/transcriptions$'), '');

  void validate() => AssistantConfig(
    endpoint: effectiveEndpoint,
    model: effectiveModel,
  ).validate();
}

/// Voice credentials never enter the settings document or chat configuration.
class VoiceSettings {
  VoiceSettings(this.db, {this.secrets = const SystemSourceSecureStore()});
  final Database db;
  final SourceSecureStore secrets;
  static const secretKey = 'assistant.voice.apiKey';

  VoiceConfig load() {
    final data = ConfigurationDatabase.readSetting(db, 'assistant', 'voice');
    return data is Map
        ? VoiceConfig(
            usePlatform: data['usePlatform'] == true,
            endpoint: data['endpoint'] as String,
            model: data['model'] as String,
          )
        : const VoiceConfig(usePlatform: true);
  }

  Future<String> key() async => await secrets.read(secretKey) ?? '';

  Future<void> save(VoiceConfig config, String key) async {
    config.validate();
    if (key.trim().isNotEmpty) {
      await secrets.write(secretKey, key.trim());
    } else if (!config.usePlatform && (await this.key()).isEmpty) {
      throw const FormatException('missingKey');
    }
    ConfigurationDatabase.writeSetting(db, 'assistant', 'voice', {
      'usePlatform': config.usePlatform,
      'endpoint': config.endpoint,
      'model': config.model,
    });
  }
}
