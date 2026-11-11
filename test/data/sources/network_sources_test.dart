import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/dlna_source.dart';
import 'package:openplayx/data/sources/media_server_sources.dart';
import 'package:openplayx/data/sources/network_file_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_connection.dart';

Future<List<int>> fetch(Uri uri, {String? range}) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    if (range != null) request.headers.set('Range', range);
    final response = await request.close();
    return await response.fold<List<int>>([], (a, b) => a..addAll(b));
  } finally {
    client.close(force: true);
  }
}

/// Fake FTP server: one folder `/pub` with a folder and a 10-byte file.
Future<ServerSocket> fakeFtp({required bool mlsd}) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final content = List.generate(10, (i) => i);
  server.listen((control) {
    ServerSocket? data;
    var offset = 0;
    var user = '';
    control.write('220 ready\r\n');
    Future<Socket> accept() => data!.first;
    control
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) async {
          final space = line.indexOf(' ');
          final verb = space < 0 ? line : line.substring(0, space);
          final arg = space < 0 ? '' : line.substring(space + 1);
          switch (verb) {
            case 'USER':
              user = arg;
              control.write('331 password\r\n');
            case 'PASS':
              control.write(
                user == 'viewer' && arg == 'secret'
                    ? '230 ok\r\n'
                    : '530 denied\r\n',
              );
            case 'TYPE' || 'OPTS':
              control.write('200 ok\r\n');
            case 'EPSV':
              data = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
              control.write('229 Entering (|||${data!.port}|)\r\n');
            case 'MLSD' when !mlsd:
              control.write('500 unknown\r\n');
            case 'MLSD' || 'LIST':
              final socket = await accept();
              control.write('150 listing\r\n');
              socket.write(
                verb == 'MLSD'
                    ? 'type=cdir; .\r\ntype=dir;modify=1; Movies\r\n'
                          'type=file;size=10; clip.mp4\r\n'
                    : 'drwxr-xr-x 1 u g 0 Jan 01 2024 Movies\r\n'
                          '-rw-r--r-- 1 u g 10 Jan 01 10:00 clip.mp4\r\n',
              );
              await socket.close();
              control.write('226 done\r\n');
            case 'SIZE':
              control.write(
                arg == '/pub/clip.mp4' ? '213 10\r\n' : '550 no\r\n',
              );
            case 'REST':
              offset = int.parse(arg);
              control.write('350 ok\r\n');
            case 'RETR':
              final socket = await accept();
              control.write('150 sending\r\n');
              socket.add(content.sublist(offset));
              offset = 0;
              await socket.close();
              control.write('226 done\r\n');
            case 'QUIT':
              control.write('221 bye\r\n');
              await control.close();
            default:
              control.write('502 no\r\n');
          }
        }, onError: (_) {});
  });
  return server;
}

void main() {
  test('addresses for the new kinds keep standard ports implicit', () {
    expect(
      SourceConnection.address(SourceKind.ftp, '192.168.1.2', path: 'pub'),
      'ftp://192.168.1.2/pub',
    );
    expect(
      SourceConnection.address(SourceKind.sftp, 'nas', port: '2222'),
      'sftp://nas:2222',
    );
    expect(
      SourceConnection.address(SourceKind.sftp, 'sftp://nas:22/home'),
      'sftp://nas/home',
    );
    expect(
      SourceConnection.address(SourceKind.emby, 'emby.lan'),
      'http://emby.lan:8096',
    );
    expect(
      SourceConnection.address(SourceKind.webdav, 'dav.lan', https: true),
      'https://dav.lan',
    );
    expect(
      SourceConnection.address(
        SourceKind.dlna,
        'http://192.168.1.3:8200/desc.xml?uuid=1',
      ),
      'http://192.168.1.3:8200/desc.xml?uuid=1',
    );
    expect(
      () => const SourceConfig(
        id: '1',
        kind: SourceKind.sftp,
        name: '',
        address: 'sftp://nas',
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const SourceConfig(
        id: '1',
        kind: SourceKind.ftp,
        name: '',
        address: 'http://nas',
      ).validate(),
      throwsFormatException,
    );
    expect(SourceKind.webdav.files && SourceKind.s3.files, isTrue);
    expect(SourceKind.emby.files || SourceKind.dlna.files, isFalse);
  });

  test('WebDAV lists, plays with ranges and stays inside its root', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final auth = <String?>[];
    server.listen((request) async {
      auth.add(request.headers.value('authorization'));
      final path = request.uri.path;
      if (request.method == 'PROPFIND' && path == '/dav/My%20Videos/') {
        request.response.statusCode = 207;
        request.response.write('''<?xml version="1.0"?>
<D:multistatus xmlns:D="DAV:">
  <D:response><D:href>/dav/My%20Videos/</D:href>
    <D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop></D:propstat></D:response>
  <D:response><D:href>http://host/dav/My%20Videos/Season%201/</D:href>
    <D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop></D:propstat></D:response>
  <D:response><D:href>/dav/My%20Videos/clip.mp4</D:href>
    <D:propstat><D:prop><D:resourcetype/><D:getcontentlength>4</D:getcontentlength></D:prop></D:propstat></D:response>
</D:multistatus>''');
      } else if (request.method == 'GET' &&
          path == '/dav/My%20Videos/clip.mp4') {
        final range = request.headers.value('range');
        request.response.headers.set('accept-ranges', 'bytes');
        if (range == 'bytes=0-0') {
          request.response.statusCode = 206;
          request.response.add([1]);
        } else if (range == 'bytes=1-2') {
          request.response.statusCode = 206;
          request.response.headers.set('content-range', 'bytes 1-2/4');
          request.response.add([2, 3]);
        } else {
          request.response.add([1, 2, 3, 4]);
        }
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
    final config = SourceConfig(
      id: 'dav',
      kind: SourceKind.webdav,
      name: '',
      address: 'http://127.0.0.1:${server.port}/dav/My%20Videos',
      username: 'viewer',
    );
    final plugin = WebDavPlugin(config, 'secret');
    addTearDown(plugin.dispose);
    final context = CallContext.forInstance('dav');
    final root = await plugin.browse(const BrowseRequest(), context);
    expect(root.entries.map((e) => (e.name, e.isFolder)), [
      ('Season 1', true),
      ('clip.mp4', false),
    ]);
    expect(root.entries.last.ref.id, '/dav/My Videos/clip.mp4');
    final stream = await plugin.resolve(
      ResolveRequest(root.entries.last.ref),
      context,
    );
    expect(stream.uri.host, '127.0.0.1');
    expect(stream.uri.toString(), isNot(contains('secret')));
    expect(await fetch(stream.uri, range: 'bytes=1-2'), [2, 3]);
    await stream.release();
    expect(
      auth.every(
        (a) => a == 'Basic ${base64Encode(utf8.encode('viewer:secret'))}',
      ),
      isTrue,
    );
    await expectLater(
      plugin.browse(
        const BrowseRequest(node: ResourceRef('dav', '/dav/other')),
        context,
      ),
      throwsA(isA<PluginException>()),
    );
  });

  for (final mlsd in [true, false]) {
    test('FTP lists (MLSD: $mlsd) and serves ranges via REST', () async {
      final server = await fakeFtp(mlsd: mlsd);
      addTearDown(server.close);
      final config = SourceConfig(
        id: 'ftp',
        kind: SourceKind.ftp,
        name: '',
        address: 'ftp://127.0.0.1:${server.port}/pub',
        username: 'viewer',
        requestTimeoutSeconds: 5,
      );
      final plugin = FtpPlugin(config, 'secret');
      addTearDown(plugin.dispose);
      final context = CallContext.forInstance('ftp');
      final root = await plugin.browse(const BrowseRequest(), context);
      expect(root.entries.map((e) => (e.ref.id, e.isFolder)), [
        ('/pub/Movies', true),
        ('/pub/clip.mp4', false),
      ]);
      final stream = await plugin.resolve(
        ResolveRequest(root.entries.last.ref),
        context,
      );
      expect(await fetch(stream.uri, range: 'bytes=3-5'), [3, 4, 5]);
      expect(await fetch(stream.uri), List.generate(10, (i) => i));
      await stream.release();
      await expectLater(
        FtpPlugin(
          SourceConfig.fromJson({...config.toJson(), 'username': 'other'}),
          'x',
        ).browse(const BrowseRequest(), context),
        throwsA(
          isA<PluginException>().having((e) => e.code, 'code', 'authRequired'),
        ),
      );
    });
  }

  test('S3 presigning matches the AWS SigV4 reference example', () {
    const signer = S3Signer(
      accessKey: 'AKIAIOSFODNN7EXAMPLE',
      secretKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
      region: 'us-east-1',
    );
    final url = signer.presign(
      Uri.parse('https://examplebucket.s3.amazonaws.com'),
      '/test.txt',
      DateTime.utc(2013, 5, 24),
      expires: const Duration(seconds: 86400),
    );
    expect(
      url.queryParameters['X-Amz-Signature'],
      'aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404',
    );
  });

  test('S3 lists prefixes as folders and signs requests', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final seen = <Uri>[];
    server.listen((request) async {
      seen.add(request.uri);
      expect(request.headers.value('authorization'), startsWith('AWS4-HMAC'));
      final token = request.uri.queryParameters['continuation-token'];
      if (request.uri.path == '/media' && token == null) {
        request.response.write(
          '''<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
<IsTruncated>true</IsTruncated><NextContinuationToken>n 1</NextContinuationToken>
<CommonPrefixes><Prefix>videos/Season 1/</Prefix></CommonPrefixes>
<Contents><Key>videos/</Key><Size>0</Size></Contents>
</ListBucketResult>''',
        );
      } else if (request.uri.path == '/media') {
        request.response.write(
          '''<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
<IsTruncated>false</IsTruncated>
<Contents><Key>videos/a b.mkv</Key><Size>9</Size></Contents>
</ListBucketResult>''',
        );
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
    final config = SourceConfig(
      id: 's3',
      kind: SourceKind.s3,
      name: '',
      address: 'http://127.0.0.1:${server.port}/media/videos',
      username: 'key',
    );
    final plugin = S3Plugin(config, 'secret');
    addTearDown(plugin.dispose);
    final root = await plugin.browse(
      const BrowseRequest(),
      CallContext.forInstance('s3'),
    );
    expect(root.entries.map((e) => (e.ref.id, e.isFolder)), [
      ('/media/videos/Season 1', true),
      ('/media/videos/a b.mkv', false),
    ]);
    expect(seen.first.queryParameters['prefix'], 'videos/');
    expect(seen.last.queryParameters['continuation-token'], 'n 1');
  });

  test('DLNA browses containers and plays item resources', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final base = 'http://127.0.0.1:${server.port}';
    String didl(String body) => const HtmlEscape().convert(
      '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/">$body</DIDL-Lite>',
    );
    server.listen((request) async {
      if (request.uri.path == '/desc.xml') {
        request.response.write(
          '''<root xmlns="urn:schemas-upnp-org:device-1-0"><device>
<deviceType>urn:schemas-upnp-org:device:MediaServer:1</deviceType><friendlyName>NAS</friendlyName>
<serviceList><service><serviceType>urn:schemas-upnp-org:service:ContentDirectory:1</serviceType>
<controlURL>/ctl/cd</controlURL></service></serviceList></device></root>''',
        );
      } else if (request.uri.path == '/ctl/cd') {
        expect(request.headers.value('soapaction'), contains('#Browse'));
        final body = await utf8.decoder.bind(request).join();
        final String result;
        if (body.contains('BrowseMetadata')) {
          result = didl(
            '<item id="7"><dc:title>Clip</dc:title>'
            '<res protocolInfo="http-get:*:video/mp4:*">$base/media/7.mp4</res></item>',
          );
        } else if (body.contains('<ObjectID>0</ObjectID>')) {
          result = didl(
            '<container id="1"><dc:title>Videos</dc:title></container>'
            '<item id="7"><dc:title>Clip</dc:title>'
            '<res protocolInfo="http-get:*:video/mp4:*">$base/media/7.mp4</res></item>'
            '<item id="8"><dc:title>Elsewhere</dc:title>'
            '<res protocolInfo="http-get:*:video/mp4:*">http://10.9.9.9/x.mp4</res></item>',
          );
        } else {
          result = didl('');
        }
        request.response.write(
          '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>'
          '<u:BrowseResponse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">'
          '<Result>$result</Result><NumberReturned>3</NumberReturned>'
          '<TotalMatches>3</TotalMatches></u:BrowseResponse></s:Body></s:Envelope>',
        );
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
    final plugin = DlnaPlugin(
      SourceConfig(
        id: 'dlna',
        kind: SourceKind.dlna,
        name: '',
        address: '$base/desc.xml',
      ),
    );
    addTearDown(plugin.dispose);
    final context = CallContext.forInstance('dlna');
    final root = await plugin.browse(const BrowseRequest(), context);
    expect(root.entries.map((e) => (e.ref.id, e.name, e.isFolder)), [
      ('c:1', 'Videos', true),
      ('i:7', 'Clip', false),
    ]);
    expect(root.nextOffset, isNull);
    final stream = await plugin.resolve(
      ResolveRequest(root.entries.last.ref),
      context,
    );
    expect(stream.uri, Uri.parse('$base/media/7.mp4'));
  });

  test('Emby requests carry Emby token headers', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final headers = Completer<HttpHeaders>();
    server.listen((request) async {
      if (!headers.isCompleted) headers.complete(request.headers);
      request.response.write('{"Items":[],"TotalRecordCount":0}');
      await request.response.close();
    });
    final config = SourceConfig(
      id: 'emby',
      kind: SourceKind.emby,
      name: '',
      address: 'http://127.0.0.1:${server.port}',
      userId: 'u',
    );
    final plugin = JellyfinPlugin(config, SourceHttp(config, 'tok'));
    addTearDown(plugin.dispose);
    await plugin.browse(const BrowseRequest(), CallContext.forInstance('emby'));
    final sent = await headers.future;
    expect(sent.value('x-emby-token'), 'tok');
    expect(plugin.manifest.id, 'source.emby');
  });

  test('servers list their newest additions for the shelf', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final paths = <String>[];
    server.listen((request) async {
      paths.add(request.uri.path);
      request.response.write(
        request.uri.path.endsWith('/Items/Latest')
            ? jsonEncode([
                {
                  'Id': 's1',
                  'Name': 'Show',
                  'Type': 'Series',
                  'IsFolder': true,
                  'ImageTags': {'Primary': 'x'},
                },
                {
                  'Id': 'm1',
                  'Name': 'Film',
                  'Type': 'Movie',
                  'MediaType': 'Video',
                },
              ])
            : jsonEncode({
                'MediaContainer': {
                  'Metadata': [
                    {
                      'ratingKey': '9',
                      'key': '/library/metadata/9',
                      'type': 'movie',
                      'title': 'Plex Film',
                      'thumb': '/t',
                    },
                  ],
                },
              }),
      );
      await request.response.close();
    });
    final address = 'http://127.0.0.1:${server.port}';
    final jf = SourceConfig(
      id: 'jf',
      kind: SourceKind.jellyfin,
      name: '',
      address: address,
      userId: 'u',
    );
    final jellyfin = JellyfinPlugin(jf, SourceHttp(jf, 't'));
    addTearDown(jellyfin.dispose);
    final latest = await jellyfin.recent(10, CallContext.forInstance('jf'));
    expect(latest.map((e) => (e.name, e.isFolder)), [
      ('Show', true),
      ('Film', false),
    ]);
    expect(latest.first.media?.artworkTypes, ['poster']);
    final px = SourceConfig(
      id: 'px',
      kind: SourceKind.plex,
      name: '',
      address: address,
    );
    final plex = PlexPlugin(px, SourceHttp(px, 't'));
    addTearDown(plex.dispose);
    final added = await plex.recent(10, CallContext.forInstance('px'));
    expect(added.single.ref.id, '/library/metadata/9');
    expect(added.single.isFolder, isFalse);
    expect(paths, contains('/library/recentlyAdded'));
  });
}
