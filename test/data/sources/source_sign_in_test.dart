import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_connection.dart';
import 'package:openplayx/data/sources/source_sign_in.dart';

void main() {
  test('connection fields use protocol defaults, accept full URLs and preserve reverse proxy paths', () {
    expect(
      SourceConnection.address(SourceKind.smb, 'nas.local'),
      'smb://nas.local',
    );
    expect(
      SourceConnection.address(
        SourceKind.smb,
        'nas.local',
        path: 'media/Movies',
      ),
      'smb://nas.local/media/Movies',
    );
    expect(
      SourceConnection.address(SourceKind.jellyfin, '192.168.1.10'),
      'http://192.168.1.10:8096',
    );
    expect(
      SourceConnection.address(
        SourceKind.jellyfin,
        'https://media.test/jellyfin',
      ),
      'https://media.test/jellyfin',
    );
    expect(
      SourceConnection.address(
        SourceKind.jellyfin,
        'media.test',
        port: '18096',
        path: 'jellyfin',
      ),
      'http://media.test:18096/jellyfin',
    );
    const existing = SourceConfig(
      id: 'j',
      kind: SourceKind.jellyfin,
      name: 'J',
      address: 'http://media.test/jellyfin',
      userId: 'u',
    );
    final values = SourceConnection.fromConfig(existing);
    expect(
      SourceConnection.address(
        existing.kind,
        values.host,
        port: '${values.port}',
        path: values.path,
        https: values.https,
      ),
      existing.address,
    );
    expect(
      () => SourceConnection.address(SourceKind.smb, 'host', port: '1445'),
      throwsFormatException,
    );
    expect(
      () => SourceConnection.address(
        SourceKind.jellyfin,
        'https://user:password@host',
      ),
      throwsFormatException,
    );
  });
  test('Jellyfin logs in with username and password; Plex authorizes, lists servers and uses server-specific credentials', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final origin = 'http://127.0.0.1:${server.port}';
    final signIn = SourceSignIn(
      plexApi: Uri.parse('$origin/api/v2/'),
      plexResources: Uri.parse('$origin/api/v2/resources'),
    );
    addTearDown(() async {
      signIn.close();
      await server.close(force: true);
    });
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      switch (request.uri.path) {
        case '/jellyfin/Users/AuthenticateByName':
          final body = jsonDecode(await utf8.decoder.bind(request).join());
          expect(body, {'Username': 'viewer', 'Pw': 'account-password'});
          expect(
            request.headers.value('authorization'),
            contains('DeviceId="instance"'),
          );
          request.response.write(
            jsonEncode({
              'User': {'Id': 'resolved-user'},
              'AccessToken': 'session-token',
            }),
          );
        case '/api/v2/pins':
          expect(request.method, 'POST');
          expect(request.uri.queryParameters['strong'], 'true');
          expect(
            request.headers.value('x-plex-client-identifier'),
            'openplayx-instance',
          );
          request.response.write(
            jsonEncode({'id': 42, 'code': 'sign-in-code', 'expiresIn': 300}),
          );
        case '/api/v2/pins/42':
          request.response.write(jsonEncode({'authToken': 'account-token'}));
        case '/api/v2/resources':
          expect(request.headers.value('x-plex-token'), 'account-token');
          request.response.write(
            jsonEncode([
              {
                'name': 'Home Server',
                'clientIdentifier': 'server-id',
                'provides': 'server',
                'accessToken': 'server-token',
                'connections': [
                  {
                    'uri': '$origin/plex',
                    'local': true,
                    'relay': false,
                    'protocol': 'http',
                  },
                ],
              },
              {
                'provides': 'player',
                'accessToken': 'ignore',
                'connections': [],
              },
            ]),
          );
        case '/plex/identity':
          expect(request.headers.value('x-plex-token'), 'server-token');
          request.response.write('{}');
        default:
          request.response.statusCode = 401;
      }
      await request.response.close();
    });
    final jellyfin = await signIn.jellyfin(
      SourceConfig(
        id: 'instance',
        kind: SourceKind.jellyfin,
        name: 'Jellyfin',
        address: '$origin/jellyfin',
        username: 'viewer',
      ),
      'account-password',
    );
    expect(jellyfin.userId, 'resolved-user');
    expect(jellyfin.token, 'session-token');
    final pin = await signIn.startPlex('instance');
    expect(pin.loginUri.host, 'app.plex.tv');
    expect(
      Uri.splitQueryString(pin.loginUri.fragment.substring(1))['clientID'],
      'openplayx-instance',
    );
    expect(pin.loginUri.toString(), isNot(contains('account-token')));
    final token = await signIn.pollPlex('instance', pin);
    final servers = await signIn.plexServers('instance', token!);
    expect(servers.single.name, 'Home Server');
    expect(
      await signIn.connectPlex('instance', servers.single),
      Uri.parse('$origin/plex'),
    );
    await expectLater(
      signIn.pollPlex(
        'instance',
        PlexPin(
          1,
          'old',
          DateTime.now().subtract(const Duration(seconds: 1)),
          pin.loginUri,
        ),
      ),
      throwsA(isA<PluginException>()),
    );
    await expectLater(
      signIn.jellyfin(
        SourceConfig(
          id: 'i',
          kind: SourceKind.jellyfin,
          name: 'Bad',
          address: origin,
          username: 'bad',
        ),
        'bad',
      ),
      throwsA(
        isA<PluginException>().having((e) => e.code, 'code', 'authRequired'),
      ),
    );
  });
}
