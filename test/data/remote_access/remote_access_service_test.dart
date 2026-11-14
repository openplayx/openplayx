import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/remote_access/remote_access_service.dart';
import 'package:openplayx/data/remote_access/remote_config.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:sqlite3/sqlite3.dart';

const uuid = '11111111-1111-4111-8111-111111111111';

String appFile({
  String server = 'relay.example',
  String id = uuid,
  List<Map<String, Object>> proxies = const [
    {'name': 'jellyfin', 'remotePort': 18096},
    {'name': 'smb', 'remotePort': 18445},
  ],
}) => jsonEncode({
  'outbound': {
    'type': 'vless',
    'tag': 'relay',
    'server': server,
    'server_port': 443,
    'uuid': id,
    'tls': {'enabled': true, 'server_name': 'relay.example'},
  },
  'proxies': proxies,
});

const source = SourceConfig(
  id: 'nas',
  kind: SourceKind.jellyfin,
  name: 'NAS',
  address: 'http://nas.invalid:8096',
  userId: 'viewer',
  remote: SourceRemote(proxy: 'jellyfin'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late RemoteAccessService service;
  String? setting() =>
      db
              .select(
                "SELECT value_json FROM settings WHERE namespace='remote_access' AND key='network'",
              )
              .firstOrNull?['value_json']
          as String?;
  setUp(() {
    db = sqlite3.openInMemory();
    service = RemoteAccessService(db);
  });
  tearDown(() => db.close());

  test('import keeps the uuid apart from the outbound, all in the settings document', () async {
    Map<String, dynamic>? checked;
    await service.importPairing(
      appFile(),
      check: (out, port) async {
        checked = out;
        expect(port, 18096);
      },
    );
    expect(checked!['uuid'], uuid);
    final saved = jsonDecode(setting()!) as Map<String, dynamic>;
    expect(saved['credential'], {'uuid': uuid});
    expect(jsonEncode(saved['outbound']), isNot(contains(uuid)));
    final json = setting()!;
    expect(json, contains('relay.example'));
    final network = service.network;
    expect(network.configured, isTrue);
    expect(network.outbound!.containsKey('tag'), isFalse);
    expect(network.proxies.map((p) => p.name), ['jellyfin', 'smb']);
    expect(network.credential, {'uuid': uuid});
    final reopened = RemoteAccessService(db);
    await reopened.load();
    expect(reopened.network.toJson(), network.toJson());
  });

  test('re-import replaces the credential and clear removes it', () async {
    await service.importPairing(appFile());
    final first = service.network.credential!;
    await service.savePolicy(service.network.copyWith(stabilitySeconds: 45));
    await service.importPairing(
      appFile(id: '22222222-2222-4222-8222-222222222222'),
    );
    final second = service.network.credential!;
    expect(second, isNot(first));
    expect(service.network.stabilitySeconds, 30);
    expect(setting(), isNot(contains(first['uuid'] as String)));
    await service.savePolicy(service.network.copyWith(stabilitySeconds: 45));
    await service.clear();
    expect(service.network.configured, isFalse);
    expect(service.network.proxies, isEmpty);
    expect(service.network.stabilitySeconds, 30);
    expect(setting(), isNot(contains(second['uuid'] as String)));
  });

  test('a failed check saves nothing', () async {
    await expectLater(
      service.importPairing(
        appFile(),
        check: (_, _) async => throw const PluginException('x', 'core failed'),
      ),
      throwsA(isA<PluginException>()),
    );
    expect(service.network.configured, isFalse);
    expect(setting(), isNull);
  });

  test('policy outside the supported range is rejected', () async {
    await expectLater(
      service.savePolicy(service.network.copyWith(probeTimeoutMs: 50)),
      throwsFormatException,
    );
  });

  test('unreadable saved settings start remote access empty', () async {
    db.execute(
      "INSERT INTO settings VALUES ('remote_access','device','local','network',?,1)",
      ['{"schemaVersion":2,"outbounds":{},"bindings":{},"policy":{}}'],
    );
    await service.load();
    expect(service.network.configured, isFalse);
    await service.importPairing(appFile());
    expect(service.network.configured, isTrue);
  });

  test('a source resolves its route by proxy name', () async {
    expect(service.attach(source).remoteAccess, isNull);
    await service.importPairing(appFile());
    final route = service.attach(source).remoteAccess!;
    expect(route.proxy, 'jellyfin');
    expect(route.remotePort, 18096);
    expect(route.credential, service.network.credential);
    expect(route.outbound.containsKey('uuid'), isFalse);
    expect(
      service
          .attach(source.copyWith(remote: const SourceRemote(proxy: 'emby')))
          .remoteAccess,
      isNull,
    );
    expect(
      service.attach(source.copyWith(clearRemote: true)).remoteAccess,
      isNull,
    );
  });

  test(
    'sources pick up imports immediately and never fall back to direct',
    () async {
      final db = sqlite3.openInMemory();
      final config = SourceConfigurationService(db);
      var checks = 0;
      final manager = SourceManager(
        configuration: config,
        remoteAccess: service,
        remoteCoreValidator: (_, _) async => checks++,
      );
      addTearDown(() async {
        await manager.dispose();
        config.close();
      });
      await manager.save(source, 'fixture-token');
      expect(manager.configs.single.remote!.proxy, 'jellyfin');
      expect(manager.configs.single.remoteAccess, isNull);
      expect(
        () => manager.withRemoteRoute(manager.configs.single),
        throwsA(
          isA<PluginException>().having(
            (e) => e.code,
            'code',
            'remoteUnavailable',
          ),
        ),
      );
      final stored = jsonDecode(
        db
                .select('SELECT config_json FROM plugin_instance_configs')
                .single['config_json']
            as String,
      ) as Map;
      expect(stored['remote'], {'proxy': 'jellyfin', 'mode': 'remoteOnly'});

      await manager.importRemotePairing(appFile());
      expect(checks, 1);
      expect(manager.configs.single.remoteAccess!.remotePort, 18096);

      await manager.importRemotePairing(
        appFile(
          proxies: const [
            {'name': 'smb', 'remotePort': 18445},
          ],
        ),
      );
      expect(manager.configs.single.remoteAccess, isNull);

      await manager.clearRemoteNetwork();
      expect(manager.remoteNetwork.configured, isFalse);
      await manager.remove('nas');
      expect(manager.configs, isEmpty);
    },
  );
}
