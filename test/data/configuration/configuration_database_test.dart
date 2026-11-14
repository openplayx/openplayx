import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/configuration/configuration_database.dart';
import 'package:openplayx/data/library/library_repository.dart';
import 'package:openplayx/services/external/external_service_registry.dart';
import 'package:openplayx/services/subtitles/asr_backend_config.dart';
import 'package:openplayx/services/subtitles/asr_model_store.dart';
import 'package:sqlite3/sqlite3.dart';

Set<Object?> tables(Database db) => {
  for (final r in db.select(
    "SELECT name FROM sqlite_master WHERE type='table'",
  ))
    r['name'],
};

void main() {
  test('configuration.sqlite3 holds exactly the configuration tables', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    ConfigurationDatabase.initialize(db);
    expect(tables(db), {
      'plugin_instance_configs',
      'settings',
      'external_services',
      'file_sources',
    });
  });

  test('source application state is library data', () {
    final repository = LibraryRepository(sqlite3.openInMemory());
    addTearDown(repository.close);
    expect(tables(repository.db), contains('source_state'));
    expect(tables(repository.configuration), isNot(contains('source_state')));
  });

  test(
    'credentials are stored on the configuration item they belong to',
    () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      final asr = AsrBackendRegistry(
        db: db,
        models: AsrModelStore(Future.value(null)),
      );
      asr.save(
        const AsrBackendConfig(
          id: 'asr-1',
          kind: 'http',
          name: 'Home',
          url: 'https://asr.example',
          modelId: 'large-v3',
        ),
      );
      asr.setToken('asr-1', 'asr-token');
      // Editing keeps the token.
      asr.save(asr.get('asr-1')!.copyWith(name: 'Office'));
      final backends = ConfigurationDatabase.readSetting(db, 'asr', 'backends');
      expect(
        (backends as List).firstWhere((b) => b['id'] == 'asr-1')['token'],
        'asr-token',
      );
      expect(await asr.credential(asr.get('asr-1')!), 'asr-token');
      expect([for (final c in asr.list()) c.id], ['embedded', 'asr-1']);

      final external = ExternalServiceRegistry(db: db);
      await external.save(
        const ExternalService(
          id: 'ext-1',
          name: 'Search',
          baseUrl: 'https://search.example',
          endpoint: 'https://search.example/mcp',
          serverName: 'search',
        ),
        token: 'ext-token',
      );
      expect(
        db
            .select("SELECT token FROM external_services WHERE id='ext-1'")
            .single['token'],
        'ext-token',
      );
      // Saving without a token keeps the saved one.
      await external.save(external.get('ext-1')!.copyWith(name: 'Web search'));
      expect(await external.token('ext-1'), 'ext-token');
    },
  );

  test('an older configuration file drops tables whose shape changed', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute('CREATE TABLE secrets (key TEXT PRIMARY KEY, value TEXT)');
    db.execute('CREATE TABLE config_applications (target_id TEXT)');
    db.execute('CREATE TABLE asr_backends (id TEXT)');
    db.execute('PRAGMA user_version = 3');
    ConfigurationDatabase.initialize(db);
    expect(tables(db), {
      'plugin_instance_configs',
      'settings',
      'external_services',
      'file_sources',
    });
    expect(
      db.select('PRAGMA user_version').single.values.single,
      ConfigurationDatabase.version,
    );
  });
}
