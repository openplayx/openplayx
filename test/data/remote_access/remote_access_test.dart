import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/remote_access/remote_config.dart';
import 'package:openplayx/data/remote_access/remote_transport.dart';
import 'package:openplayx/data/sources/source_config.dart';

RemoteAccessConfig config({
  RemoteConnectionMode mode = RemoteConnectionMode.automatic,
}) => RemoteAccessConfig(
  lineId: 'line',
  homeId: 'home',
  serviceId: 'jellyfin',
  remoteAddress: 'http://nas.invalid:8096',
  remotePort: 18096,
  credentialRef: 'remote.source.1',
  mode: mode,
  localAddress: 'https://nas.example:8920',
  localTlsSha256: List.filled(64, 'a').join(),
);
void main() {
  test('round trip keeps stable source/media identity without embedding outbound secrets', () {
    final source = SourceConfig(
      id: 'source',
      kind: SourceKind.jellyfin,
      name: 'NAS',
      address: 'http://nas.invalid:8096',
      userId: 'user',
      remoteAccess: config(),
    );
    final decoded = SourceConfig.fromJson(
      jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.id, source.id);
    expect(decoded.remoteAccess!.serviceId, 'jellyfin');
    expect(decoded.credentialRef, isNull);
    expect(jsonEncode(source.toJson()), isNot(contains('uuid')));
    decoded.validate();
    expect(
      () => source
          .copyWith(
            remoteAccess: RemoteAccessConfig.fromJson({
              ...config().toJson(),
              'credentialRef': 'remote.other.1',
            }),
          )
          .validate(),
      throwsFormatException,
    );
  });
  test('coalesces LAN probes, holds result briefly, rechecks after network changes', () async {
    var probes = 0;
    var time = DateTime(2026);
    final selector = RemotePathSelector(
      probe: (_, _) async {
        probes++;
        return true;
      },
      now: () => time,
    );
    expect(
      await Future.wait(
        List.generate(20, (_) => selector.useLocal('source', config())),
      ),
      everyElement(isTrue),
    );
    expect(probes, 1);
    time = time.add(const Duration(seconds: 31));
    await selector.useLocal('source', config());
    expect(probes, 2);
    selector.networkChanged();
    await selector.useLocal('source', config());
    expect(probes, 3);
  });
  test(
    'unreachable or mismatched LAN falls back; localOnly never initiates relay',
    () async {
      final selector = RemotePathSelector(probe: (_, _) async => false);
      expect(await selector.useLocal('s', config()), isFalse);
      await expectLater(
        selector.useLocal('s', config(mode: RemoteConnectionMode.localOnly)),
        throwsException,
      );
      final remote = RemotePathSelector(
        probe: (_, _) async => throw StateError('must not probe'),
      );
      expect(
        await remote.useLocal(
          's',
          config(mode: RemoteConnectionMode.remoteOnly),
        ),
        isFalse,
      );
    },
  );
  test('automatic mode rejects HTTP and unverified identities', () {
    expect(
      () => RemoteAccessConfig.fromJson({
        ...config().toJson(),
        'localAddress': 'http://nas.local',
      }),
      throwsFormatException,
    );
    expect(
      () => RemoteAccessConfig.fromJson({
        ...config().toJson(),
        'localTlsSha256': '',
      }),
      throwsFormatException,
    );
    expect(
      () => RemoteAccessConfig.endpoint('https://user:password@nas.local'),
      throwsFormatException,
    );
  });
  test(
    'pairing accepts TLS and rejects insecure or external file configuration',
    () {
      final pair = {
        'version': 1,
        ...config().toJson(),
        'outbound': {
          'type': 'vless',
          'server': 'relay.example',
          'server_port': 443,
          'uuid': '11111111-1111-4111-8111-111111111111',
          'tls': {'enabled': true, 'server_name': 'relay.example'},
        },
      };
      expect(RemotePairing.parse(jsonEncode(pair)).outbound['type'], 'vless');
      (pair['outbound'] as Map)['tls'] = {
        'enabled': true,
        'server_name': 'relay.example',
        'insecure': true,
      };
      expect(
        () => RemotePairing.parse(jsonEncode(pair)),
        throwsFormatException,
      );
      (pair['outbound'] as Map)['tls'] = {
        'enabled': true,
        'server_name': 'relay.example',
        'certificate_path': '/tmp/secret',
      };
      expect(
        () => RemotePairing.parse(jsonEncode(pair)),
        throwsFormatException,
      );
    },
  );
  test('lease scopes sockets to configured origin and closes once', () async {
    var closed = 0;
    final lease = RemotePathLease(
      Uri.parse('http://nas.invalid'),
      onClose: () => closed++,
    );
    final client = HttpClient();
    lease.configure(client);
    await expectLater(
      client.getUrl(Uri.parse('http://other.invalid')),
      throwsException,
    );
    client.close(force: true);
    lease.close();
    lease.close();
    expect(closed, 1);
  });
  test('TLS keeps logical hostname and rejects a changed pin before sending credentials', () async {
    const root = 'test/fixtures/remote_access/test-only';
    final serverContext = SecurityContext()
      ..useCertificateChain('$root.crt')
      ..usePrivateKey('$root.key');
    final trusted = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates('test/fixtures/remote_access/test-ca.crt');
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      serverContext,
    );
    var requests = 0;
    server.listen((request) async {
      requests++;
      expect(request.headers.value('host'), 'media.test:8443');
      expect(request.headers.value('authorization'), 'Bearer scoped-token');
      request.response.write('media');
      await request.response.close();
    });
    final address = Uri.parse('https://media.test:8443/video');
    final client = HttpClient();
    final lease = RemotePathLease(address, loopbackPort: server.port);
    lease.configure(client, securityContext: trusted);
    try {
      final request = await client.getUrl(address);
      request.headers.set('authorization', 'Bearer scoped-token');
      final response = await request.close();
      expect(await utf8.decoder.bind(response).join(), 'media');
      expect(requests, 1);
    } finally {
      client.close(force: true);
      lease.close();
    }
    final wrongPin = HttpClient();
    RemotePathLease(
      address,
      loopbackPort: server.port,
      localTlsSha256: List.filled(64, '0').join(),
    ).configure(wrongPin, securityContext: trusted);
    await expectLater(wrongPin.getUrl(address), throwsException);
    expect(requests, 1);
    wrongPin.close(force: true);
    final wrongName = HttpClient();
    final badAddress = Uri.parse('https://wrong.test:8443/video');
    RemotePathLease(
      badAddress,
      loopbackPort: server.port,
    ).configure(wrongName, securityContext: trusted);
    await expectLater(wrongName.getUrl(badAddress), throwsException);
    expect(requests, 1);
    wrongName.close(force: true);
    await server.close(force: true);
  });
  test('SMB socket factory maps 445 only inside its source zone', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((s) {
      s.listen((data) {
        s.add(data);
      });
    });
    final path = RemotePathLease(
      Uri.parse('smb://nas.invalid/Media'),
      loopbackPort: server.port,
    );
    await path.runWithTcp(
      () async {
        final socket = await Socket.connect('nas.invalid', 445);
        socket.add([1, 2, 3]);
        expect(await socket.first, [1, 2, 3]);
        socket.destroy();
        await expectLater(
          Socket.connect('other.invalid', 445),
          throwsException,
        );
        await expectLater(Socket.connect('nas.invalid', 139), throwsException);
      },
      logicalHost: 'nas.invalid',
      logicalPort: 445,
    );
    // Outside the scoped zone a direct loopback connection still works.
    final direct = await Socket.connect('127.0.0.1', server.port);
    direct.destroy();
    path.close();
    await server.close();
  });
}
