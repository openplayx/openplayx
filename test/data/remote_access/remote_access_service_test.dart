import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/remote_access/remote_access_service.dart';
import 'package:openplayx/data/remote_access/remote_config.dart';
import 'package:openplayx/data/remote_access/remote_transport.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:sqlite3/sqlite3.dart';

const uuid = '11111111-1111-4111-8111-111111111111';
const outbound = {
  'type': 'vless',
  'server': 'relay.example',
  'server_port': 443,
  'uuid': uuid,
  'tls': {'enabled': true, 'server_name': 'relay.example'},
};
const source = SourceConfig(
  id: 'nas',
  kind: SourceKind.jellyfin,
  name: 'NAS',
  address: 'http://nas.invalid:8096',
  userId: 'viewer',
);
RemoteAccessConfig connection(String ref, {String line = 'primary'}) =>
    RemoteAccessConfig(
      lineId: line,
      homeId: 'home',
      serviceId: 'jellyfin',
      remoteAddress: 'http://nas.invalid:8096',
      remotePort: 18096,
      credentialRef: ref,
      outboundOptions: ({...outbound}..remove('uuid')),
    );
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late RemoteAccessService service;
  late String ref;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('opx-config-');
    service = RemoteAccessService(directory);
    FlutterSecureStorage.setMockInitialValues({});
    ref = await RemoteCredentialStore.stage(source.id, {'uuid': uuid});
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test('JSON is authoritative, credentials are referenced, save is distinct from apply', () async {
    await service.load();
    final draft = service.desired.copyWith(
      bindings: {source.id: RemoteAccessBinding(connection(ref))},
    );
    await service.save(draft, expectedRevision: 0);
    expect(service.desired.revision, 1);
    expect(service.active.revision, 0);
    final json = await File('${directory.path}/remote_access.json')
        .readAsString();
    expect(json, isNot(contains(uuid)));
    expect(json, contains('relay.example'));
    await service.apply(expectedRevision: 1, sources: [source]);
    expect(service.active.revision, 1);
    final reopened = RemoteAccessService(directory);
    await reopened.load();
    expect(reopened.attach(source).remoteAccess!.lineId, 'primary');
  });
  test(
    'concurrent editors conflict and explicit restore creates a new revision',
    () async {
      await service.save(const RemoteAccessDocument(), expectedRevision: 0);
      final other = RemoteAccessService(directory);
      await other.load();
      await service.save(
        service.desired.copyWith(stabilitySeconds: 45),
        expectedRevision: 1,
      );
      await expectLater(
        other.save(
          other.desired.copyWith(stabilitySeconds: 60),
          expectedRevision: 1,
        ),
        throwsA(isA<PluginException>()),
      );
      final restored = await service.restore(expectedRevision: 2);
      expect(restored.revision, 3);
      expect(restored.stabilitySeconds, 30);
    },
  );
  test('failed apply retains last applied state while desired revision stays saved', () async {
    await service.save(
      service.desired.copyWith(
        bindings: {source.id: RemoteAccessBinding(connection(ref))},
      ),
      expectedRevision: 0,
    );
    await service.apply(expectedRevision: 1, sources: [source]);
    await service.save(
      service.desired.copyWith(stabilitySeconds: 80),
      expectedRevision: 1,
    );
    await expectLater(
      service.apply(
        expectedRevision: 2,
        sources: [source],
        check: (_) async => throw const SocketException('fixture'),
      ),
      throwsA(isA<SocketException>()),
    );
    expect(service.active.revision, 1);
    expect(service.desired.revision, 2);
    expect(service.error, 'applyFailed');
    final reopened = RemoteAccessService(directory);
    await reopened.load();
    expect(reopened.active.revision, 1);
    expect(reopened.desired.revision, 2);
  });
  test(
    'corrupt and unknown schemas are retained and cannot be default-saved',
    () async {
      final file = File('${directory.path}/remote_access.json');
      await file.writeAsString('{broken');
      await expectLater(
        service.save(const RemoteAccessDocument(), expectedRevision: 0),
        throwsFormatException,
      );
      expect(await file.readAsString(), '{broken');
      await file.writeAsString('{"schemaVersion":99,"revision":22}');
      await expectLater(
        RemoteAccessService(directory).load(),
        throwsFormatException,
      );
      expect(jsonDecode(await file.readAsString())['schemaVersion'], 99);
    },
  );
  test('legacy SQLite remote binding is migrated once without changing source identity', () async {
    FlutterSecureStorage.setMockInitialValues({
      'remote.nas.legacy': jsonEncode(outbound),
    });
    final db = sqlite3.openInMemory();
    final config = SourceConfigurationService(db);
    final legacy = source.copyWith(
      revision: 1,
      remoteAccess: connection('remote.nas.legacy'),
    );
    db.execute('INSERT INTO plugin_instance_configs VALUES (?,?,?,?,?,?)', [
      legacy.id,
      legacy.pluginId,
      jsonEncode(legacy.toJson()),
      2,
      1,
      1,
    ]);
    final manager = SourceManager(configuration: config, remoteAccess: service);
    await manager.load();
    expect(manager.configs.single.id, 'nas');
    expect(manager.configs.single.revision, 1);
    expect(manager.configs.single.remoteAccess!.lineId, 'primary');
    final saved = jsonDecode(
      db
              .select('SELECT config_json FROM plugin_instance_configs')
              .single['config_json']
          as String,
    ) as Map;
    expect(saved.containsKey('remoteAccess'), isFalse);
    expect(saved['remoteManaged'], isTrue);
    expect(await File('${directory.path}/remote_access.json').exists(), isTrue);
    await manager.reload();
    expect(service.desired.revision, 1);
    await manager.dispose();
    config.close();
  });
  test(
    'backup identity and source scope validation reject unrelated targets',
    () {
      final primary = connection(ref);
      final other = RemoteAccessConfig.fromJson({
        ...primary.toJson(),
        'homeId': 'different',
        'lineId': 'backup',
      });
      expect(
        () => RemoteAccessBinding.fromJson(
          RemoteAccessBinding(primary, backups: [other]).toJson(),
        ),
        throwsFormatException,
      );
      expect(
        () => RemoteAccessDocument(
          bindings: {'other-source': RemoteAccessBinding(primary)},
        ).validate(),
        throwsFormatException,
      );
    },
  );
  test(
    'discarded staged secrets are removed and applied/backup references remain',
    () async {
      final discard = await RemoteCredentialStore.stage('nas', {'uuid': uuid});
      await service.save(
        service.desired.copyWith(
          bindings: {'nas': RemoteAccessBinding(connection(ref))},
        ),
        expectedRevision: 0,
      );
      await service.cleanupStaged([('nas', ref), ('nas', discard)]);
      expect(await const FlutterSecureStorage().read(key: ref), isNotNull);
      expect(await const FlutterSecureStorage().read(key: discard), isNull);
    },
  );
  test('explicit recovery preserves damaged bytes and never reuses an issued revision', () async {
    await service.save(const RemoteAccessDocument(), expectedRevision: 0);
    await service.save(
      service.desired.copyWith(stabilitySeconds: 45),
      expectedRevision: 1,
    );
    final file = File('${directory.path}/remote_access.json');
    await file.writeAsString('{damaged');
    final reopened = RemoteAccessService(directory);
    await expectLater(reopened.load(), throwsFormatException);
    await reopened.recoverFromBackup();
    expect(reopened.desired.revision, 3);
    expect(reopened.active.revision, 0);
    final copies = await directory
        .list()
        .where((f) => f.path.contains('.damaged.'))
        .toList();
    expect(await File(copies.single.path).readAsString(), '{damaged');
  });
  test('shared public line parameters are stored once and inconsistent aliases are rejected', () async {
    final second = await RemoteCredentialStore.stage('second', {'uuid': uuid});
    final first = connection(ref);
    final other = connection(second);
    final doc = RemoteAccessDocument(
      bindings: {
        'nas': RemoteAccessBinding(first),
        'second': RemoteAccessBinding(other),
      },
    );
    final json = doc.toJson();
    expect((json['lines'] as Map).length, 1);
    expect(
      (json['bindings'] as Map)['nas']['primary']['outboundOptions'],
      isNull,
    );
    final roundtrip = RemoteAccessDocument.fromJson(json);
    expect(
      roundtrip.bindings['nas']!.primary.outboundOptions!['server'],
      'relay.example',
    );
    final different = RemoteAccessConfig.fromJson({
      ...other.toJson(),
      'outboundOptions': {
        ...other.outboundOptions!,
        'server': 'another.example',
      },
    });
    expect(
      () => RemoteAccessDocument(
        bindings: {
          'nas': RemoteAccessBinding(first),
          'second': RemoteAccessBinding(different),
        },
      ).validate(),
      throwsFormatException,
    );
  });
  test(
    'failed core apply retains saved keys and blocks requests after restart',
    () async {
      final db = sqlite3.openInMemory();
      final config = SourceConfigurationService(db);
      final manager = SourceManager(
        configuration: config,
        remoteAccess: service,
        remoteCoreValidator: (_) async =>
            throw const SocketException('fixture core failure'),
      );
      await expectLater(
        manager.save(
          source.copyWith(remoteAccess: connection(ref)),
          'fixture-media-token',
        ),
        throwsA(isA<SocketException>()),
      );
      expect(manager.configs.single.remoteAccess, isNull);
      expect(manager.configs.single.remoteRequiredRevision, 1);
      await manager.discardRemoteSecret('nas', ref);
      expect(await const FlutterSecureStorage().read(key: ref), isNotNull);
      await expectLater(
        manager.browse('nas', const BrowseRequest(limit: 1)),
        throwsA(
          isA<PluginException>().having(
            (e) => e.code,
            'code',
            'remoteNotApplied',
          ),
        ),
      );
      await manager.dispose();
      final reopened = SourceManager(
        configuration: config,
        remoteAccess: RemoteAccessService(directory),
        remoteCoreValidator: (_) async {},
      );
      await reopened.load();
      expect(reopened.configs.single.remoteAccess, isNull);
      await expectLater(
        reopened.browse('nas', const BrowseRequest(limit: 1)),
        throwsA(
          isA<PluginException>().having(
            (e) => e.code,
            'code',
            'remoteNotApplied',
          ),
        ),
      );
      await reopened.applyRemoteSettings(1);
      expect(reopened.configs.single.remoteAccess, isNotNull);
      await reopened.dispose();
      config.close();
    },
  );
  test('source revision conflict compensates JSON without activating the staged binding', () async {
    final db = sqlite3.openInMemory();
    final config = SourceConfigurationService(db);
    final manager = SourceManager(
      configuration: config,
      remoteAccess: service,
      remoteCoreValidator: (_) async {},
    );
    await manager.save(source, 'fixture-media-token');
    await expectLater(
      manager.save(
        source.copyWith(remoteAccess: connection(ref)),
        'replacement-token',
      ),
      throwsA(isA<PluginException>().having((e) => e.code, 'code', 'conflict')),
    );
    expect(service.desired.bindings, isEmpty);
    expect(service.active.bindings, isEmpty);
    expect(manager.configs.single.remoteAccess, isNull);
    await manager.dispose();
    config.close();
  });
  test(
    'apply reloads source changes made by another window before binding',
    () async {
      final config = SourceConfigurationService(sqlite3.openInMemory());
      final manager = SourceManager(
        configuration: config,
        remoteAccess: service,
        remoteCoreValidator: (_) async {},
      );
      await manager.save(source, 'fixture-token');
      final other = SourceManager(
        configuration: config,
        remoteAccess: RemoteAccessService(directory),
        remoteCoreValidator: (_) async {},
      );
      await other.load();
      await other.save(
        other.configs.single.copyWith(name: 'Changed in another window'),
        '',
      );
      await service.save(
        service.desired.copyWith(
          bindings: {source.id: RemoteAccessBinding(connection(ref))},
        ),
        expectedRevision: 0,
      );
      await manager.applyRemoteSettings(1);
      expect(manager.configs.single.name, 'Changed in another window');
      expect(manager.configs.single.remoteAccess, isNotNull);
      await manager.dispose();
      await other.dispose();
      config.close();
    },
  );
}
