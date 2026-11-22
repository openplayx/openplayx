import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/remote_access/remote_config.dart';
import 'package:openplayx/data/remote_access/remote_transport.dart';
import 'package:openplayx/data/sources/network_file_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';

void main() {
  test('WebDAV uses its leased transport for listing, attachments, ranged playback and writes', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final verbs = <String>[];
    var acquisitions = 0, releases = 0;
    server.listen((request) async {
      verbs.add(request.method);
      expect(
        request.headers.value('authorization'),
        'Basic ${base64Encode(utf8.encode('viewer:secret'))}',
      );
      expect(request.headers.value('host'), 'remote.invalid');
      await request.drain<void>();
      switch (request.method) {
        case 'PROPFIND':
          request.response.statusCode = 207;
          request.response.write(
            '<d:multistatus xmlns:d="DAV:"><d:response><d:href>/dav/clip.mp4</d:href><d:propstat><d:prop><d:getcontentlength>5</d:getcontentlength></d:prop></d:propstat></d:response></d:multistatus>',
          );
        case 'GET':
          request.response.statusCode = 200;
          request.response.write('video');
        case 'PUT':
          request.response.statusCode = 201;
        case 'MOVE':
          expect(
            request.headers.value('destination'),
            startsWith('http://remote.invalid/dav/'),
          );
          request.response.statusCode = 201;
        default:
          request.response.statusCode = 201;
      }
      await request.response.close();
    });
    const config = SourceConfig(
      id: 'dav',
      kind: SourceKind.webdav,
      name: 'DAV',
      address: 'http://remote.invalid/dav',
      username: 'viewer',
      remote: SourceRemote(proxy: 'dav'),
      remoteAccess: RemoteAccessConfig(
        proxy: 'dav',
        remotePort: 18000,
        credential: {'uuid': '11111111-1111-4111-8111-111111111111'},
        outbound: {
          'type': 'vless',
          'server': 'relay.test',
          'server_port': 443,
          'tls': {'enabled': true, 'server_name': 'relay.test'},
        },
      ),
    );
    config.validate();
    final plugin = WebDavPlugin(
      config,
      'secret',
      remoteConnection: (source) async {
        acquisitions++;
        return RemotePathLease(
          Uri.parse(source.address),
          loopbackPort: server.port,
          onClose: () => releases++,
        );
      },
    );
    try {
      final listed = await plugin.list('/dav');
      expect(listed.single.path, '/dav/clip.mp4');
      expect(utf8.decode(await plugin.read('/dav/clip.mp4', 100)), 'video');
      final playable = await plugin.open('/dav/clip.mp4', 'clip.mp4');
      final client = HttpClient();
      try {
        final response = await (await client.getUrl(playable.uri)).close();
        expect(await utf8.decoder.bind(response).join(), 'video');
      } finally {
        client.close(force: true);
        await playable.release();
      }
      await plugin.writeNewStream(
        Stream.value(utf8.encode('video')),
        5,
        'uploaded.mp4',
        CallContext.forInstance('dav'),
      );
      expect(verbs, containsAll(['PROPFIND', 'GET', 'PUT', 'MOVE']));
      expect(acquisitions, 1);
    } finally {
      await plugin.dispose();
      await server.close(force: true);
    }
    expect(releases, 1);
  });
}
