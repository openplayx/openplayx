import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/file_sources.dart';
import 'package:openplayx/data/sources/media_server_sources.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/stream_gateway.dart';

void main() {
  test('local browsing pages, resolves files, rejects cross-instance and symlink escape', () async {
    final root = await Directory.systemTemp.createTemp('source-test-');
    final outside = await Directory.systemTemp.createTemp('outside-');
    addTearDown(() async {
      await root.delete(recursive: true);
      await outside.delete(recursive: true);
    });
    await Directory('${root.path}/folder').create();
    final file = await File('${root.path}/video.mp4').writeAsBytes([1, 2, 3]);
    await Link('${root.path}/escape').create(outside.path);
    final source = LocalFolderPlugin(
      SourceConfig(
        id: 'local',
        kind: SourceKind.local,
        name: 'Local',
        address: root.path,
      ),
    );
    final context = CallContext.forInstance('local');
    final first = await source.browse(const BrowseRequest(limit: 1), context);
    expect(first.entries.single.isFolder, isTrue);
    expect(first.nextOffset, 1);
    final second = await source.browse(
      const BrowseRequest(offset: 1, limit: 1),
      context,
    );
    expect(second.entries.single.name, 'video.mp4');
    expect(second.nextOffset, isNull);
    expect(
      (await source.resolve(
        ResolveRequest(second.entries.single.ref),
        context,
      )).uri,
      Uri.file(await file.resolveSymbolicLinks()),
    );
    await expectLater(
      source.resolve(ResolveRequest(ResourceRef('other', file.path)), context),
      throwsA(isA<PluginException>()),
    );
    await expectLater(
      source.browse(
        BrowseRequest(node: ResourceRef('local', '${root.path}/escape')),
        context,
      ),
      throwsA(isA<PluginException>()),
    );
  });

  test('loopback stream supports HEAD, bounded/suffix ranges, rejects invalid ranges and closes', () async {
    final dir = await Directory.systemTemp.createTemp('range-test-');
    final file = await File('${dir.path}/bytes')
        .writeAsBytes(List.generate(256, (i) => i));
    final stream = await StreamGateway.randomAccess(
      length: 256,
      open: file.open,
    );
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await stream.release();
      await dir.delete(recursive: true);
    });
    Future<HttpClientResponse> get(String method, String? range) async {
      final request = await client.openUrl(method, stream.uri);
      if (range != null) request.headers.set('Range', range);
      return request.close();
    }

    final response = await get('GET', 'bytes=10-19');
    expect(response.statusCode, 206);
    expect(response.headers.value('content-range'), 'bytes 10-19/256');
    expect(
      await response.fold<List<int>>([], (a, b) => a..addAll(b)),
      List.generate(10, (i) => i + 10),
    );
    final suffix = await get('GET', 'bytes=-3');
    expect(await suffix.fold<List<int>>([], (a, b) => a..addAll(b)), [
      253,
      254,
      255,
    ]);
    final head = await get('HEAD', null);
    expect(head.contentLength, 256);
    await head.drain<void>();
    final invalid = await get('GET', 'bytes=999-');
    expect(invalid.statusCode, 416);
    await invalid.drain<void>();
    await stream.release();
    await stream.release();
    client.close(force: true);
    final closedClient = HttpClient();
    addTearDown(() => closedClient.close(force: true));
    await expectLater(
      () async => (await closedClient.getUrl(stream.uri)).close(),
      throwsA(isA<SocketException>()),
    );
  });

  test('media servers browse, authenticate, select versions and proxy Range without exposing tokens', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    server.listen((request) async {
      requests.add(request.uri.path);
      expect(
        request.headers.value('x-plex-token') ??
            request.headers.value('authorization'),
        contains('secret'),
      );
      request.response.headers.contentType = ContentType.json;
      Object result;
      switch (request.uri.path) {
        case '/base/Users/user/Items':
          expect(request.uri.queryParameters['Limit'], '1');
          result = {
            'Items': [
              {
                'Id': 'movie',
                'Name': 'Movie',
                'MediaType': 'Video',
                'MediaSources': [
                  {'Id': 'v1'},
                  {'Id': 'v2'},
                ],
              },
            ],
            'TotalRecordCount': 2,
          };
        case '/base/Users/user/Items/movie':
          result = {
            'Id': 'movie',
            'MediaType': 'Video',
            'MediaSources': [
              {'Id': 'v1', 'Name': '1080p'},
              {'Id': 'v2', 'Name': '4K'},
            ],
          };
        case '/base/library/sections':
          result = {
            'MediaContainer': {
              'Directory': [
                {'key': '1', 'title': 'Movies'},
              ],
              'size': 1,
            },
          };
        case '/base/library/sections/1/all':
          result = {
            'MediaContainer': {
              'Metadata': [
                {
                  'key': '/library/metadata/7',
                  'title': 'Plex Movie',
                  'type': 'movie',
                },
              ],
              'size': 1,
            },
          };
        case '/base/library/metadata/7':
          result = {
            'MediaContainer': {
              'Metadata': [
                {
                  'Media': [
                    {
                      'Part': [
                        {'key': '/library/parts/7/file.mp4'},
                      ],
                    },
                  ],
                },
              ],
            },
          };
        case '/base/Videos/movie/stream':
        case '/base/library/parts/7/file.mp4':
          expect(request.headers.value('range'), 'bytes=1-2');
          request.response.statusCode = 206;
          request.response.headers.set('content-range', 'bytes 1-2/4');
          request.response.add([2, 3]);
          await request.response.close();
          return;
        default:
          request.response.statusCode = 401;
          await request.response.close();
          return;
      }
      request.response.write(jsonEncode(result));
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    for (final kind in [SourceKind.jellyfin, SourceKind.plex]) {
      final config = SourceConfig(
        id: kind.name,
        kind: kind,
        name: kind.label,
        address: 'http://127.0.0.1:${server.port}/base',
        userId: 'user',
      );
      final http = SourceHttp(config, 'secret');
      final SourceCapability source = kind == SourceKind.plex
          ? PlexPlugin(config, http)
          : JellyfinPlugin(config, http);
      addTearDown(() => (source as Plugin).dispose());
      final context = CallContext.forInstance(config.id);
      final root = await source.browse(const BrowseRequest(limit: 1), context);
      var entry = root.entries.single;
      expect(entry.isFolder, isTrue);
      final children = await source.browse(
        BrowseRequest(node: entry.ref),
        context,
      );
      entry = children.entries.first;
      final stream = await source.resolve(ResolveRequest(entry.ref), context);
      expect(stream.uri.toString(), isNot(contains('secret')));
      final request = await client.getUrl(stream.uri);
      request.headers.set('Range', 'bytes=1-2');
      final response = await request.close();
      expect(response.statusCode, 206);
      expect(await response.fold<List<int>>([], (a, b) => a..addAll(b)), [
        2,
        3,
      ]);
      await stream.release();
      expect(
        () => http.uri('https://evil.test/file'),
        throwsA(isA<PluginException>()),
      );
      expect(() => http.uri('/../file'), throwsA(isA<PluginException>()));
      await expectLater(
        http.json('/forbidden'),
        throwsA(
          isA<PluginException>().having((e) => e.code, 'code', 'authRequired'),
        ),
      );
    }
    expect(requests, contains('/base/library/parts/7/file.mp4'));
  });

  test(
    'source configuration rejects embedded secrets and unsupported SMB ports',
    () {
      for (final address in [
        'smb://user:pass@host/share',
        'smb://host:1445/share',
        'smb://host/share/../secret',
      ]) {
        expect(
          () => SourceConfig(
            id: '1',
            kind: SourceKind.smb,
            name: 'SMB',
            address: address,
          ).validate(),
          throwsFormatException,
        );
      }
    },
  );
}
