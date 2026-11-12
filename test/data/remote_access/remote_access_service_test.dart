import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  late Directory directory;
  late RemoteAccessService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('opx-remote-');
    service = RemoteAccessService(directory);
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'import keeps the uuid in secure storage and the rest in JSON',
    () async {
      Map<String, dynamic>? checked;
      await service.importPairing(
        appFile(),
        check: (out, port) async {
          checked = out;
          expect(port, 18096);
        },
      );
      expect(checked!['uuid'], uuid);
      final json = await File('${directory.path}/remote_access.json')
          .readAsString();
      expect(json, isNot(contains(uuid)));
      expect(json, contains('relay.example'));
      final network = service.network;
      expect(network.configured, isTrue);
      expect(network.outbound!.containsKey('tag'), isFalse);
      expect(network.proxies.map((p) => p.name), ['jellyfin', 'smb']);
      expect(
        jsonDecode(
          (await const FlutterSecureStorage().read(
            key: network.credentialRef!,
          ))!,
        ),
        {'uuid': uuid},
      );
      final reopened = RemoteAccessService(directory);
      await reopened.load();
      expect(reopened.network.toJson(), network.toJson());
    },
  );

  test('re-import replaces the credential and clear removes it', () async {
    await service.importPairing(appFile());
    final first = service.network.credentialRef!;
    await service.savePolicy(service.network.copyWith(stabilitySeconds: 45));
    await service.importPairing(
      appFile(id: '22222222-2222-4222-8222-222222222222'),
    );
    final second = service.network.credentialRef!;
    expect(second, isNot(first));
    expect(service.network.stabilitySeconds, 30);
    expect(await const FlutterSecureStorage().read(key: first), isNull);
    await service.savePolicy(service.network.copyWith(stabilitySeconds: 45));
    await service.clear();
    expect(service.network.configured, isFalse);
    expect(service.network.proxies, isEmpty);
    expect(service.network.stabilitySeconds, 30);
    expect(await const FlutterSecureStorage().read(key: second), isNull);
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
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
    expect(
      await File('${directory.path}/remote_access.json').exists(),
      isFalse,
    );
  });

  test('policy outside the supported range is rejected', () async {
    await expectLater(
      service.savePolicy(service.network.copyWith(probeTimeoutMs: 50)),
      throwsFormatException,
    );
  });

  test(
    'an earlier schema is moved aside and remote access starts empty',
    () async {
      final file = File('${directory.path}/remote_access.json');
      await file.writeAsString(
        '{"schemaVersion":2,"revision":4,"outbounds":{},"bindings":{},"policy":{}}',
      );
      for (final name in ['state', 'backup', 'revision']) {
        await File('${directory.path}/remote_access.$name.json')
            .writeAsString('{}');
      }
      await service.load();
      expect(service.network.configured, isFalse);
      expect(await file.exists(), isFalse);
      final names = await directory
          .list()
          .map((f) => f.path.split(Platform.pathSeparator).last)
          .toList();
      expect(
        names.where((n) => n.startsWith('remote_access.discarded.')),
        hasLength(1),
      );
      expect(
        names.where((n) => n.contains('.state.') || n.contains('.backup.')),
        isEmpty,
      );
      await service.importPairing(appFile());
      expect(service.network.configured, isTrue);
    },
  );

  test('a source resolves its route by proxy name', () async {
    expect(service.attach(source).remoteAccess, isNull);
    await service.importPairing(appFile());
    final route = service.attach(source).remoteAccess!;
    expect(route.proxy, 'jellyfin');
    expect(route.remotePort, 18096);
    expect(route.credentialRef, service.network.credentialRef);
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
