import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/configuration/configuration_database.dart';
import 'package:openplayx/data/remote_access/discovered_source.dart';
import 'package:openplayx/data/remote_access/relay_subscription.dart';
import 'package:openplayx/data/remote_access/remote_access_service.dart';
import 'package:openplayx/data/remote_access/remote_config.dart';
import 'package:openplayx/data/sources/source_config.dart';

import 'relay_subscription_test.dart' as fixtures;

Map<String, dynamic> profile({
  String revision = '1',
  String status = 'enabled',
  String name = 'NAS',
}) {
  final data = fixtures.profile(revision: revision, readyNode: 'node_a');
  final item = <String, dynamic>{
    'serviceId': 'service_a',
    'connectorId': 'connector_a',
    'name': name,
    'connectorName': 'Home',
    'type': 'smb',
    'status': status,
  };
  data['services'] = status == 'enabled'
      ? [
          {...item, 'remotePort': 18000},
        ]
      : <Object>[];
  data['sourceCatalog'] = {
    'schemaVersion': 1,
    'userId': 'user_a',
    'revision': revision,
    'items': [item],
  };
  return data;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late SourceConfigurationService config;
  late RemoteAccessService remote;
  late SourceManager manager;
  late Map<String, dynamic> response;
  bool offline = false;
  setUp(() async {
    db = sqlite3.openInMemory();
    config = SourceConfigurationService(db);
    response = profile();
    offline = false;
    final subscription = RelaySubscription(
      db,
      client: MockClient((request) async {
        if (offline) throw http.ClientException('offline');
        if (request.url.path == '/v1/auth/login')
          return http.Response(
            jsonEncode({
              'accessToken': 'a',
              'refreshToken': 'r',
              'expiresIn': 900,
            }),
            200,
          );
        if (request.url.path == '/v1/auth/logout')
          return http.Response('{}', 200);
        return http.Response(jsonEncode(response), 200);
      }),
    );
    remote = RemoteAccessService(db, subscription: subscription);
    await remote.load();
    await remote.loginPlatform('a@example.test', 'password');
    manager = SourceManager(configuration: config, remoteAccess: remote);
    await manager.load();
    await remote.refreshPlatform();
  });
  tearDown(() async {
    await manager.dispose();
    db.close();
  });

  test('discovery is pending only; setup/hide/restore/sync never duplicate a connection', () async {
    expect(manager.configs, isEmpty);
    final entry = manager.pendingDiscoveredSources.single;
    expect(entry.name, 'NAS');
    expect(entry.draft().remote!.mode, RemoteConnectionMode.remoteOnly);
    await manager.hideDiscoveredSource(entry, true);
    expect(manager.pendingDiscoveredSources, isEmpty);
    await manager.hideDiscoveredSource(entry, false);
    await manager.save(entry.draft(), '');
    final id = manager.configs.single.id;
    expect(manager.pendingDiscoveredSources, isEmpty);
    await manager.syncDiscoveredSources();
    expect(manager.configs.single.id, id);
    await manager.hideDiscoveredSource(entry, true);
    expect(manager.visibleConfigs, isEmpty);
    expect(manager.configs.single.id, id);
    await manager.hideDiscoveredSource(entry, false);
    expect(manager.visibleConfigs.single.id, id);
  });

  test('exact legacy IDs migrate without losing credentials, ranges or explicit mode', () async {
    await manager.save(
      const SourceConfig(
        id: 'legacy',
        kind: SourceKind.smb,
        name: 'NAS',
        address: 'smb://host/media',
        username: 'viewer',
        remote: SourceRemote(proxy: 'service_a'),
      ),
      'password',
    );
    await manager.reload();
    final migrated = manager.configs.single;
    expect(migrated.id, 'legacy');
    expect(migrated.address, 'smb://host/media');
    expect(migrated.remote!.accountId, 'user_a');
    expect(migrated.remote!.mode, RemoteConnectionMode.remoteOnly);
    expect(await manager.storedSecret('legacy'), 'password');
    expect(manager.pendingDiscoveredSources, isEmpty);
  });

  test('failed sync preserves directory; disabled and deleted are distinct and block new access', () async {
    final entry = manager.pendingDiscoveredSources.single;
    await manager.save(entry.draft(), '');
    offline = true;
    await expectLater(
      manager.syncDiscoveredSources(),
      throwsA(isA<http.ClientException>()),
    );
    expect(manager.discoveredSources.single.status, 'enabled');
    expect(manager.configs, hasLength(1));
    offline = false;
    response = profile(revision: '2', status: 'disabled');
    await manager.syncDiscoveredSources();
    expect(manager.discoveredSources.single.status, 'disabled');
    expect(
      () => manager.withRemoteRoute(manager.configs.single),
      throwsA(anything),
    );
    response = profile(revision: '3', status: 'removed');
    await manager.syncDiscoveredSources();
    expect(manager.discoveredSources.single.status, 'removed');
    expect(manager.configs, hasLength(1));
  });

  test('logout removes account sources and scopes from UI while preserving local configuration', () async {
    await manager.save(manager.pendingDiscoveredSources.single.draft(), '');
    final id = manager.configs.single.id;
    final library = LibraryService(sqlite3.openInMemory());
    library.followSources(manager);
    library.addFileSource(id, root: '/private', name: 'Private');
    expect(library.fileSourceList(), hasLength(1));
    await remote.logoutPlatform();
    expect(manager.configs, isEmpty);
    expect(manager.discoveredSources, isEmpty);
    expect(library.fileSourceList(), isEmpty);
    expect(config.load(), hasLength(1));
    library.close();
  });

  test('each source follows its owning Connector node, without the global majority shortcut', () async {
    response = profile(revision: '2');
    (response['services'] as List).add({
      'serviceId': 'service_b',
      'connectorId': 'connector_b',
      'name': 'B',
      'type': 'smb',
      'remotePort': 18001,
    });
    ((response['sourceCatalog'] as Map)['items'] as List).add({
      'serviceId': 'service_b',
      'connectorId': 'connector_b',
      'name': 'B',
      'connectorName': 'Office',
      'type': 'smb',
      'status': 'enabled',
    });
    (response['serviceStatus'] as List).add({
      'serviceId': 'service_b',
      'readyNodeIds': ['node_b'],
    });
    await manager.syncDiscoveredSources();
    final entries = manager.pendingDiscoveredSources;
    expect(
      manager
          .withRemoteRoute(entries.first.draft())
          .remoteAccess!
          .outbound['server'],
      'a.relay.test',
    );
    expect(
      manager
          .withRemoteRoute(entries.last.draft())
          .remoteAccess!
          .outbound['server'],
      'b.relay.test',
    );
  });

  test(
    'persisted library ownership is enforced before SourceManager loads',
    () {
      final library = LibraryService(sqlite3.openInMemory());
      final saved = SourceConfigurationService(library.configuration);
      final entry = manager.pendingDiscoveredSources.single;
      saved.save(entry.draft(), expectedRevision: 0);
      library.addFileSource(
        entry.draft().id,
        root: '/private',
        name: 'Private',
      );
      expect(library.fileSourceList(), isEmpty);
      ConfigurationDatabase.writeSetting(
        library.configuration,
        'relay_account',
        'session',
        {'userId': 'user_a', 'accessToken': 'a', 'refreshToken': 'r'},
      );
      expect(library.fileSourceList(), hasLength(1));
      ConfigurationDatabase.writeSetting(
        library.configuration,
        'relay_account',
        'session',
        {'userId': 'other', 'accessToken': 'a', 'refreshToken': 'r'},
      );
      expect(library.fileSourceList(), isEmpty);
      expect(library.repository.enabledFileSourceIds(), isEmpty);
      library.close();
    },
  );

  test('service renames follow Connector while local aliases and source IDs survive', () async {
    await manager.save(manager.pendingDiscoveredSources.single.draft(), '');
    final id = manager.configs.single.id;
    response = profile(revision: '2', name: 'New NAS');
    await manager.syncDiscoveredSources();
    expect(manager.configs.single.name, 'New NAS');
    expect(manager.configs.single.id, id);
    await manager.save(manager.configs.single.copyWith(name: 'My alias'), '');
    response = profile(revision: '3', name: 'Another NAS');
    await manager.syncDiscoveredSources();
    expect(manager.configs.single.name, 'My alias');
  });

  test('HTTPS descriptions seed verified LAN mode; malformed catalogs never replace a good snapshot', () async {
    final item =
        ((response['sourceCatalog'] as Map)['items'] as List).single as Map;
    item['type'] = 'jellyfin';
    item['sourceDescriptor'] = {
      'schemaVersion': 1,
      'kind': 'jellyfin',
      'application': {
        'scheme': 'https',
        'basePath': '/media',
        'tlsServerName': 'media.example.test',
      },
      'localAccess': {
        'mode': 'direct_https',
        'endpoint': 'https://media.example.test:8920/media',
        'identity': {'kind': 'tls_certificate_sha256', 'value': 'a' * 64},
      },
    };
    final entry = DiscoveredSource.parseCatalog(response).single;
    final draft = entry.draft();
    draft.copyWith(userId: 'viewer').validate();
    expect(draft.address, 'https://media.example.test/media');
    expect(draft.remote!.mode, RemoteConnectionMode.automatic);
    expect(draft.remote!.managedLocal, isTrue);
    final malformed = profile(revision: '2');
    (malformed['sourceCatalog'] as Map)['userId'] = 'other';
    response = malformed;
    await expectLater(manager.syncDiscoveredSources(), throwsFormatException);
    expect(remote.platformProfile!.revision, BigInt.one);
  });
}
