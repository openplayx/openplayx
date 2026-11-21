import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/data/remote_access/relay_subscription.dart';
import 'package:openplayx/data/remote_access/remote_access_service.dart';
import 'package:openplayx/data/remote_access/remote_config.dart';

import 'remote_access_service_test.dart' show appFile;

Map<String, dynamic> profile({
  String revision = '1',
  int minutes = 30,
  bool empty = false,
  String? readyNode,
}) => {
  'schemaVersion': 1,
  'revision': revision,
  'validUntil': DateTime.now()
      .add(Duration(minutes: minutes))
      .toIso8601String(),
  'userId': 'user_a',
  'deviceId': 'device_a',
  'credential': {
    'type': 'vless',
    'uuid': '11111111-1111-4111-8111-111111111111',
  },
  'nodes': empty
      ? []
      : [
          {
            'nodeId': 'node_b',
            'name': 'B',
            'status': 'enabled',
            'host': 'b.relay.test',
            'port': 443,
            'tlsServerName': 'b.relay.test',
            'sortOrder': 20,
          },
          {
            'nodeId': 'node_a',
            'name': 'A',
            'status': 'enabled',
            'host': 'a.relay.test',
            'port': 443,
            'tlsServerName': 'a.relay.test',
            'sortOrder': 10,
          },
        ],
  'services': [
    {'serviceId': 'service_a', 'remotePort': 18000},
  ],
  'serviceStatus': [
    {
      'serviceId': 'service_a',
      'readyNodeIds': [?readyNode],
      'observedAt': null,
    },
  ],
};
void main() {
  late Database db;
  late RemoteAccessService remote;
  late Map<String, dynamic> responseProfile;
  final requests = <http.Request>[];
  bool bound = false, denied = false, offline = false;
  setUp(() {
    db = sqlite3.openInMemory();
    responseProfile = profile();
    requests.clear();
    bound = false;
    denied = false;
    offline = false;
    final client = MockClient((request) async {
      requests.add(request);
      expect(request.url.origin, 'https://api.openplayx.com');
      expect(request.followRedirects, isFalse);
      if (offline) throw http.ClientException('offline');
      final path = request.url.path;
      if (path == '/v1/auth/registration/request') {
        expect(request.headers['Authorization'], isNull);
        return http.Response('{"status":"accepted"}', 202);
      }
      if (path == '/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'accessToken': 'access',
            'refreshToken': 'refresh',
            'expiresIn': 900,
          }),
          200,
        );
      }
      expect(request.headers['Authorization'], 'Bearer access');
      if (path == '/v1/relay/me/devices') {
        bound = true;
        return http.Response('{"device":{"deviceId":"device_a"}}', 201);
      }
      if (path == '/v1/auth/logout') return http.Response('{}', 200);
      if (denied) {
        return http.Response('{"error":{"code":"relay_device_revoked"}}', 401);
      }
      if (!bound) {
        return http.Response(
          '{"error":{"code":"device_session_required"}}',
          403,
        );
      }
      return http.Response(jsonEncode(responseProfile), 200);
    });
    remote = RemoteAccessService(
      db,
      subscription: RelaySubscription(db, client: client),
    );
  });
  tearDown(() {
    remote.dispose();
    db.close();
  });
  test('registration requests email setup without creating an authenticated session', () async {
    await remote.account.requestRegistration('  owner@example.com  ');
    expect(requests.single.url.path, '/v1/auth/registration/request');
    expect(jsonDecode(requests.single.body), {'email': 'owner@example.com'});
    expect(remote.account.signedIn, isFalse);
  });
  test('platform defaults load on login, register once, sort nodes and preserve service identities', () async {
    await remote.load();
    expect(remote.usePlatform, isTrue);
    expect(remote.network.configured, isFalse);
    await remote.loginPlatform('user@example.com', 'private-password');
    expect(remote.network.outbound!['server'], 'a.relay.test');
    expect(remote.network.proxies.single.name, 'service_a');
    expect(
      remote.network
          .routeFor(const SourceRemote(proxy: 'service_a'))!
          .remotePort,
      18000,
    );
    await remote.refreshPlatform();
    expect(
      requests.where((r) => r.url.path == '/v1/relay/me/devices').length,
      1,
    );
    responseProfile = profile(revision: '2');
    (responseProfile['nodes'] as List).first['sortOrder'] = 0;
    await remote.refreshPlatform();
    // No Connector report yet: the first listed node.
    expect(remote.network.outbound!['server'], 'b.relay.test');
    expect(remote.followsConnector, isFalse);
    // The Connector reports its node; the device follows without a choice.
    responseProfile = profile(revision: '3', readyNode: 'node_a');
    (responseProfile['nodes'] as List).first['sortOrder'] = 0;
    await remote.refreshPlatform();
    expect(remote.followsConnector, isTrue);
    expect(remote.network.outbound!['server'], 'a.relay.test');
    await remote.selectPlatform();
    expect(remote.network.outbound!['server'], 'a.relay.test');
  });
  test('custom import remains authoritative during platform refresh; restore keeps the custom document', () async {
    await remote.importPairing(appFile());
    await remote.loginPlatform('user@example.com', 'password');
    expect(remote.usePlatform, isFalse);
    expect(remote.network.outbound!['server'], 'relay.example');
    responseProfile = profile(revision: '2');
    await remote.refreshPlatform();
    expect(remote.network.outbound!['server'], 'relay.example');
    await remote.selectPlatform();
    expect(remote.network.outbound!['server'], 'a.relay.test');
    final saved =
        db
                .select(
                  "SELECT value_json FROM settings WHERE namespace='remote_access' AND key='network'",
                )
                .single['value_json']
            as String;
    expect(saved, contains('relay.example'));
    final reopened = RemoteAccessService(db);
    await reopened.load();
    expect(reopened.usePlatform, isTrue);
    expect(reopened.network.outbound!['server'], 'a.relay.test');
    reopened.dispose();
  });
  test('expired freshness keeps a fixed route; withdrawn nodes and revoked devices remove it', () async {
    await remote.loginPlatform('user@example.com', 'password');
    responseProfile = profile(revision: '2', empty: true);
    await remote.refreshPlatform();
    expect(remote.network.configured, isFalse);
    responseProfile = profile(revision: '3');
    await remote.refreshPlatform();
    expect(remote.network.configured, isTrue);
    remote.platformProfile = RelayDeviceProfile.parse(profile(minutes: -1));
    expect(remote.network.configured, isTrue);
    expect(
      remote.network.routeFor(const SourceRemote(proxy: 'service_a')),
      isNotNull,
    );
    remote.platformProfile = null;
    denied = true;
    await expectLater(
      remote.refreshPlatform(),
      throwsA(isA<RelayApiException>()),
    );
    expect(remote.account.signedIn, isFalse);
    expect(remote.network.configured, isFalse);
  });
  test('transient failures retain the lease; rollback is rejected; sign out clears platform credentials', () async {
    await remote.loginPlatform('user@example.com', 'password');
    responseProfile = profile(revision: '5');
    await remote.refreshPlatform();
    responseProfile = profile(revision: '4');
    await expectLater(remote.refreshPlatform(), throwsFormatException);
    expect(remote.platformProfile!.revision, BigInt.from(5));
    offline = true;
    await expectLater(
      remote.refreshPlatform(),
      throwsA(isA<http.ClientException>()),
    );
    expect(remote.network.configured, isTrue);
    offline = false;
    await remote.logoutPlatform();
    expect(remote.account.signedIn, isFalse);
    expect(remote.network.configured, isFalse);
  });
  test('devices follow the Connector node; a removed node falls back until the next report', () async {
    responseProfile = profile(readyNode: 'node_b');
    await remote.loginPlatform('user@example.com', 'password');
    await remote.testPlatformNodes(
      probe: (node) async {
        if (node['nodeId'] == 'node_b') {
          throw Exception('unreachable');
        }
        return const Duration(milliseconds: 12);
      },
    );
    expect(remote.nodeLatencyMs, {'node_a': 12, 'node_b': null});
    expect(remote.network.outbound!['server'], 'b.relay.test');
    // node_b is rebuilt as node_c: until the Connector reports, use the first node.
    responseProfile = profile(revision: '2', readyNode: 'node_b');
    (responseProfile['nodes'] as List).removeWhere(
      (n) => n['nodeId'] == 'node_b',
    );
    await remote.refreshPlatform();
    expect(remote.followsConnector, isFalse);
    expect(remote.network.outbound!['server'], 'a.relay.test');
    responseProfile = profile(revision: '3', readyNode: 'node_c');
    (responseProfile['nodes'] as List).add({
      'nodeId': 'node_c',
      'name': 'C',
      'status': 'enabled',
      'host': 'c.relay.test',
      'port': 443,
      'tlsServerName': 'c.relay.test',
      'sortOrder': 30,
    });
    await remote.refreshPlatform();
    expect(remote.network.outbound!['server'], 'c.relay.test');
    final reopened = RemoteAccessService(db);
    await reopened.load();
    expect(reopened.network.outbound!['server'], 'c.relay.test');
    reopened.dispose();
  });
  test(
    'malformed profiles, disabled nodes and excessive leases are rejected',
    () {
      expect(
        () => RelayDeviceProfile.parse(profile(minutes: 60)),
        throwsFormatException,
      );
      final p = profile();
      (p['nodes'] as List).first['status'] = 'disabled';
      expect(() => RelayDeviceProfile.parse(p), throwsFormatException);
    },
  );
}
