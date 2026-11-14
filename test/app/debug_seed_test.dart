import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/debug_seed/debug_seed.dart';
import 'package:openplayx/app/debug_seed/seed_template.dart';
import 'package:openplayx/data/configuration/configuration_database.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/remote_access/remote_access_service.dart';
import 'package:openplayx/services/conversations/assistant_store.dart';
import 'package:openplayx/services/external/external_service_registry.dart';
import 'package:openplayx/services/subtitles/asr_backend_config.dart';
import 'package:openplayx/services/subtitles/asr_model_store.dart';
import 'package:sqlite3/sqlite3.dart';

const uuid = '11111111-1111-4111-8111-111111111111';

Map<String, Object?> seed({String smbName = '211 NAS'}) => {
  'version': 1,
  'sources': [
    {
      'id': 'nas-smb',
      'kind': 'smb',
      'name': smbName,
      'address': 'smb://192.168.1.211/media',
      'username': 'openplayx',
      'secret': 'smb-pass',
    },
    {
      'id': 'nas-plex',
      'kind': 'plex',
      'name': 'Plex',
      'address': 'http://192.168.1.211:13240',
      'secret': 'plex-token',
    },
  ],
  'fileSources': [
    {
      'id': 'movies',
      'source': 'nas-smb',
      'root': '/media/Movies',
      'name': '电影',
    },
  ],
  'scanExtensions': ['mkv', 'MP4'],
  'externalServices': [
    {
      'id': 'bt',
      'name': '家里下载',
      'baseUrl': 'http://192.168.1.211:18780/',
      'token': 'bt-token',
    },
  ],
  'asr': [
    {
      'id': 'asr-211',
      'kind': 'http',
      'name': '211 Whisper',
      'url': 'http://192.168.1.211:9000',
      'modelId': 'large-v3',
      'allowInsecureHttp': true,
      'uploadConsent': true,
      'token': 'asr-token',
    },
  ],
  'assistant': {
    'endpoint': 'https://api.deepseek.com',
    'model': 'deepseek-v4-pro',
    'cloudAllowed': true,
    'apiKey': 'sk-test',
  },
  'metadata': {'language': 'zh-CN', 'tmdbToken': 'tmdb-token'},
  'remoteAccess': {
    'pairing': {
      'outbound': {
        'type': 'vless',
        'tag': 'relay',
        'server': 'relay.example',
        'server_port': 443,
        'uuid': uuid,
        'tls': {'enabled': true, 'server_name': 'relay.example'},
      },
      'proxies': [
        {'name': 'smb', 'remotePort': 18445},
      ],
    },
  },
  'appearance': {'themeMode': 'dark', 'developerMode': true},
  'diagnostics': true,
};

void main() {
  group('template', () {
    test('.env parsing handles comments, export and quotes', () {
      expect(
        parseEnv(
          '# comment\n'
          'A=1\n'
          'export B = two words \n'
          'C="quo\\"ted\\n"\n'
          "D='\$literal'\n"
          'not a pair\n',
        ),
        {'A': '1', 'B': 'two words', 'C': 'quo"ted\n', 'D': r'$literal'},
      );
    });

    test('variables are filled inside strings; missing ones are all named', () {
      expect(
        resolveSeed(
          {
            'a': r'${X}',
            'b': [r'http://${HOST}:80', 3, true],
          },
          {'X': 'q"uote', 'HOST': 'nas'},
        ),
        {
          'a': 'q"uote',
          'b': ['http://nas:80', 3, true],
        },
      );
      expect(
        () => resolveSeed({'a': r'${B} ${A}'}, {}),
        throwsA(
          isA<MissingSeedVariables>().having((e) => e.names, 'names', [
            'A',
            'B',
          ]),
        ),
      );
    });
  });

  group('import', () {
    late Database db;
    setUp(() => db = sqlite3.openInMemory());
    tearDown(() => db.close());

    test('every section lands on its configuration item', () async {
      final report = await DebugSeed.apply(db, jsonEncode(seed()));
      expect(report.failed, isEmpty);
      expect(report.applied, hasLength(11));

      final sources = SourceConfigurationService(db);
      expect([for (final c in sources.load()) c.id], ['nas-smb', 'nas-plex']);
      expect(sources.readSecret('nas-plex'), 'plex-token');
      expect(sources.scanExtensions(), ['mkv', 'mp4']);
      expect(sources.appearance('themeMode'), 'dark');
      expect(sources.appearance('developerMode'), 'true');
      expect(
        db.select('SELECT source_id, root, name FROM file_sources').single,
        {'source_id': 'nas-smb', 'root': '/media/Movies', 'name': '电影'},
      );

      final external = ExternalServiceRegistry(db: db);
      await external.load();
      expect(external.get('bt')!.baseUrl, 'http://192.168.1.211:18780');
      expect(external.get('bt')!.available, isFalse);
      expect(await external.token('bt'), 'bt-token');

      final asr = AsrBackendRegistry(
        db: db,
        models: AsrModelStore(Future.value(null)),
      );
      final backend = asr.get('asr-211')!;
      expect(backend.uploadConsentAt, isNotNull);
      expect(await asr.credential(backend), 'asr-token');

      final assistant = AssistantStore(
        sqlite3.openInMemory(),
        configuration: db,
      );
      expect(assistant.loadConfig().cloudAllowed, isTrue);
      expect(await assistant.key(), 'sk-test');

      String? setting(String namespace, String key) =>
          ConfigurationDatabase.readSetting(db, namespace, key)?.toString();
      expect(setting('metadata', 'tmdbToken'), 'tmdb-token');
      expect(setting('metadata', 'language'), 'zh-CN');
      expect(setting('metadata', 'tmdbRevision'), isNotNull);
      expect(setting('diagnostics', 'enabled'), 'true');

      final remote = RemoteAccessService(db);
      await remote.load();
      expect(remote.network.credential, {'uuid': uuid});
      expect(remote.network.proxies.single.name, 'smb');
    });

    test(
      'the same seed is imported once; a changed one upserts by id',
      () async {
        await DebugSeed.apply(db, jsonEncode(seed()));
        expect((await DebugSeed.apply(db, jsonEncode(seed()))).skipped, isTrue);
        final again = await DebugSeed.apply(
          db,
          jsonEncode(seed(smbName: 'Renamed NAS')),
        );
        expect(again.skipped, isFalse);
        expect(again.failed, isEmpty);
        final sources = SourceConfigurationService(db).load();
        expect(sources, hasLength(2));
        expect(sources.first.name, 'Renamed NAS');
        expect(db.select('SELECT 1 FROM file_sources'), hasLength(1));
        expect(db.select('SELECT 1 FROM external_services'), hasLength(1));
      },
    );

    test('a failing item is reported and the rest still applies', () async {
      final report = await DebugSeed.apply(
        db,
        jsonEncode({
          'version': 1,
          'sources': [
            {'id': 'here', 'kind': 'local', 'name': 'Here', 'address': '/tmp'},
          ],
          'fileSources': [
            {'id': 'orphan', 'source': 'missing'},
          ],
          'metadata': {'language': 'en-US'},
        }),
      );
      expect(report.failed.keys, ['sources/here', 'fileSources/orphan']);
      expect(report.applied, ['metadata']);
      expect(
        ConfigurationDatabase.readSetting(db, 'metadata', 'language'),
        'en-US',
      );
    });

    test('a seed without version 1 is rejected', () async {
      await expectLater(
        DebugSeed.apply(db, jsonEncode({'sources': []})),
        throwsFormatException,
      );
    });
  });
}
