import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/configuration/source_secure_store.dart';
import 'package:openplayx/data/sources/cloud_oauth.dart';
import 'package:openplayx/data/sources/dropbox_source.dart';
import 'package:openplayx/data/sources/onedrive_source.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:sqlite3/sqlite3.dart';

class MemorySecrets implements SourceSecureStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class Headers implements HttpHeaders {
  final values = <String, String>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name.toLowerCase()] = value.toString();
  }

  @override
  String? value(String name) => values[name.toLowerCase()];
  @override
  set contentType(ContentType? value) {
    set('content-type', value ?? '');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Response extends Stream<List<int>> implements HttpClientResponse {
  Response(
    this.statusCode,
    Object? body, {
    Map<String, String> headers = const {},
    bool raw = false,
  }) : bytes = raw ? body as List<int> : utf8.encode(jsonEncode(body)) {
    headers.forEach(this.headers.set);
  }
  final List<int> bytes;
  @override
  final int statusCode;
  @override
  final Headers headers = Headers();
  @override
  bool get isRedirect => [301, 302, 303, 307, 308].contains(statusCode);
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Request implements HttpClientRequest {
  Request(this.method, this.uri, this.handler);
  @override
  final String method;
  @override
  final Uri uri;
  final FutureOr<Response> Function(Request) handler;
  @override
  final Headers headers = Headers();
  final body = StringBuffer();
  @override
  bool followRedirects = true;
  @override
  void write(Object? object) {
    body.write(object);
  }

  @override
  Future<HttpClientResponse> close() async => handler(this);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Client implements HttpClient {
  Client(this.handler);
  final FutureOr<Response> Function(Request) handler;
  final requests = <Request>[];
  bool closed = false;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final r = Request(method, url, handler);
    requests.add(r);
    return r;
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CloudTokens tokens([String value = 'access']) =>
    CloudTokens(value, 'refresh', DateTime.now().add(const Duration(hours: 1)));
CloudTokenSession session(SourceKind kind) =>
    CloudTokenSession(kind, tokens(), persist: (_) async {});
SourceConfig config(SourceKind kind, {String root = ''}) => SourceConfig(
  id: 'account-a',
  kind: kind,
  name: '',
  address: '${kind.name}://account',
  cloudRootId: root,
);
final context = CallContext.forInstance('account-a');

void main() {
  test(
    'PKCE callback verifies state, redirect and duplicates; denial cancels',
    () {
      final app = CloudOAuthApp(SourceKind.dropbox, clientId: 'public-id');
      final attempt = CloudOAuthAttempt(app);
      expect(attempt.verifier.length, 43);
      expect(attempt.loginUri.queryParameters['code_challenge_method'], 'S256');
      expect(attempt.loginUri.queryParameters['token_access_type'], 'offline');
      Uri callback(Map<String, String> query) =>
          app.redirect.replace(queryParameters: query);
      expect(
        attempt.code(callback({'state': attempt.state, 'code': 'ok'})),
        'ok',
      );
      expect(
        attempt.code(
          callback({'state': attempt.state, 'error': 'access_denied'}),
        ),
        isNull,
      );
      for (final bad in [
        callback({'state': 'other', 'code': 'stolen'}),
        callback({'state': attempt.state, 'code': 'ok'})
            .replace(path: '/wrong'),
        Uri.parse('${app.redirect}?state=${attempt.state}&code=a&code=b'),
      ]) {
        expect(() => attempt.code(bad), throwsA(isA<PluginException>()));
      }
    },
  );

  test(
    'refresh is merged and rotated refresh token is persisted once',
    () async {
      final gate = Completer<CloudTokens>();
      var refreshes = 0, saves = 0;
      final s = CloudTokenSession(
        SourceKind.onedrive,
        CloudTokens('expired', 'old-refresh', DateTime(2000)),
        refresh: (_) {
          refreshes++;
          return gate.future;
        },
        persist: (next) async {
          saves++;
          expect(next.refreshToken, 'rotated');
        },
      );
      final calls = List.generate(10, (_) => s.access());
      gate.complete(
        CloudTokens(
          'new',
          'rotated',
          DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      expect(await Future.wait(calls), List.filled(10, 'new'));
      expect(refreshes, 1);
      expect(saves, 1);
    },
  );

  test(
    'shared account disconnection closes root picker clients immediately',
    () async {
      final shared = session(SourceKind.dropbox);
      final client = Client((_) => Response(200, {}));
      final source = DropboxSource(
        config(SourceKind.dropbox),
        shared,
        client: client,
        ownsSession: false,
      );
      shared.close();
      expect(client.closed, isTrue);
      await expectLater(
        source.browse(const BrowseRequest(), context),
        throwsA(isA<PluginException>()),
      );
      await source.dispose();
    },
  );

  test(
    'late 401 for an old access token reuses the completed refresh',
    () async {
      var refreshes = 0;
      final s = CloudTokenSession(
        SourceKind.dropbox,
        tokens('old'),
        refresh: (_) async {
          refreshes++;
          return tokens('new');
        },
        persist: (_) async {},
      );
      expect(await s.access(force: true, rejectedToken: 'old'), 'new');
      expect(await s.access(force: true, rejectedToken: 'old'), 'new');
      expect(refreshes, 1);
    },
  );

  test('root picker and runtime share a persistent session; stale rotation is rejected', () async {
    final service = SourceConfigurationService(sqlite3.openInMemory());
    final store = MemorySecrets();
    final manager = SourceManager(configuration: service, secureStore: store);
    await manager.save(config(SourceKind.dropbox), tokens().encode());
    final saved = manager.configs.single;
    final first = await manager.cloudTokenSession(saved);
    final second = await manager.cloudTokenSession(saved);
    expect(identical(first, second), isTrue);
    final old = service.readSecret(saved.id);
    await first.persist(tokens('rotated'));
    expect(service.readSecret(saved.id), isNot(old));
    expect(
      CloudTokens.decode((await manager.storedSecret(saved.id))!).accessToken,
      'rotated',
    );
    expect(store.values.length, 1);
    await manager.save(saved.copyWith(name: 'changed'), '');
    expect(first.isClosed, isTrue);
    await expectLater(
      first.persist(tokens('stale')),
      throwsA(isA<PluginException>()),
    );
    expect(store.values.length, 1);
    expect(
      CloudTokens.decode((await manager.storedSecret(saved.id))!).accessToken,
      'rotated',
    );
    await manager.remove(saved.id);
    expect(store.values, isEmpty);
    await manager.dispose();
    service.close();
  });

  test(
    'disconnect during refresh prevents late credential resurrection',
    () async {
      final gate = Completer<CloudTokens>();
      var saved = false;
      final s = CloudTokenSession(
        SourceKind.dropbox,
        CloudTokens('old', 'refresh', DateTime(2000)),
        refresh: (_) => gate.future,
        persist: (_) async {
          saved = true;
        },
      );
      final pending = s.access();
      final assertion = expectLater(pending, throwsA(isA<PluginException>()));
      s.close();
      gate.complete(tokens());
      await assertion;
      expect(saved, isFalse);
    },
  );

  test('OS storage references survive restart, isolate accounts and clear on removal', () async {
    final service = SourceConfigurationService(sqlite3.openInMemory());
    final store = MemorySecrets();
    var manager = SourceManager(configuration: service, secureStore: store);
    await manager.save(config(SourceKind.dropbox), tokens('one').encode());
    await manager.save(
      SourceConfig(
        id: 'account-b',
        kind: SourceKind.dropbox,
        name: '',
        address: 'dropbox://account',
      ),
      tokens('two').encode(),
    );
    expect(
      service.readSecret('account-a'),
      startsWith('secure-source:account-a:'),
    );
    expect(
      jsonEncode(service.load().map((e) => e.toJson()).toList()),
      isNot(contains('refresh')),
    );
    await manager.dispose();
    manager = SourceManager(configuration: service, secureStore: store);
    await manager.load();
    expect(
      CloudTokens.decode((await manager.storedSecret('account-a'))!)
          .accessToken,
      'one',
    );
    expect(
      CloudTokens.decode((await manager.storedSecret('account-b'))!)
          .accessToken,
      'two',
    );
    final refA = service.readSecret('account-a');
    final refB = service.readSecret('account-b');
    service.db.execute(
      'UPDATE plugin_instance_configs SET secret=? WHERE instance_id=?',
      [refA, 'account-b'],
    );
    expect(
      await manager.storedSecret('account-b'),
      isNull,
    ); // cross-account reference denied
    service.db.execute(
      'UPDATE plugin_instance_configs SET secret=? WHERE instance_id=?',
      [refB, 'account-b'],
    );
    await manager.remove('account-a');
    expect(store.values.length, 1);
    expect(service.readSecret('account-a'), isNull);
    await manager.dispose();
    service.close();
  });

  test(
    'cloud directory scan keeps stable library identity after rename',
    () async {
      var filename = '中文 movie.mp4';
      final client = Client((r) {
        final data = jsonDecode(r.body.toString()) as Map;
        final path = data['path'];
        if (r.uri.path.endsWith('get_metadata')) {
          final root = path == 'id:root' || path == '/selected';
          return Response(200, {
            '.tag': 'folder',
            'id': root ? 'id:root' : 'id:folder',
            'name': root ? 'selected' : 'Season 1',
            'path_lower': root ? '/selected' : '/selected/season 1',
          });
        }
        expect(r.uri.path.endsWith('list_folder'), isTrue);
        return Response(200, {
          'has_more': false,
          'entries': path == 'id:root'
              ? [
                  {
                    '.tag': 'folder',
                    'id': 'id:folder',
                    'name': 'Season 1',
                    'path_lower': '/selected/season 1',
                  },
                ]
              : [
                  {
                    '.tag': 'file',
                    'id': 'id:movie',
                    'name': filename,
                    'path_lower': '/selected/season 1/$filename',
                    'size': 6000000000,
                  },
                ],
        });
      });
      await HttpOverrides.runZoned(() async {
        final service = SourceConfigurationService(sqlite3.openInMemory());
        final manager = SourceManager(
          configuration: service,
          secureStore: MemorySecrets(),
        );
        final library = LibraryService(sqlite3.openInMemory());
        try {
          await manager.save(
            config(SourceKind.dropbox, root: 'id:root'),
            tokens().encode(),
          );
          final files = await manager.scan('account-a').toList();
          expect(files.single.ref.id, 'id:movie');
          final binding = library.addFileSource('account-a', name: 'selected');
          await library.scan(binding, manager);
          final before = library.resourceFor(
            const ResourceRef('account-a', 'id:movie'),
          )!['id'];
          filename = 'renamed.mp4';
          await library.scan(binding, manager);
          expect(
            library.resourceFor(
              const ResourceRef('account-a', 'id:movie'),
            )!['id'],
            before,
          );
          expect(library.db.select('SELECT * FROM resources').length, 1);
        } finally {
          await manager.dispose();
          library.close();
          service.close();
        }
      }, createHttpClient: (_) => client);
    },
  );

  test(
    'Dropbox pages retain stable IDs, unicode and >4 GB sizes across offsets',
    () async {
      final client = Client((r) {
        final data = jsonDecode(r.body.toString()) as Map<String, dynamic>;
        if (r.uri.path.endsWith('/continue')) {
          expect(data['cursor'], 'cursor-1');
          return Response(200, {
            'entries': [
              {
                '.tag': 'file',
                'id': 'id:last',
                'name': '终集.mp4',
                'path_lower': '/终集.mp4',
                'size': 6,
              },
            ],
            'has_more': false,
          });
        }
        return Response(200, {
          'entries': [
            {
              '.tag': 'file',
              'id': 'id:one',
              'name': '中文 # 1.mkv',
              'path_lower': '/中文 # 1.mkv',
              'size': 6000000000,
            },
            {
              '.tag': 'folder',
              'id': 'id:folder',
              'name': 'Season 1',
              'path_lower': '/season 1',
            },
          ],
          'has_more': true,
          'cursor': 'cursor-1',
        });
      });
      final source = DropboxSource(
        config(SourceKind.dropbox),
        session(SourceKind.dropbox),
        client: client,
      );
      final first = await source.browse(const BrowseRequest(limit: 1), context);
      expect(first.entries.single.ref.id, 'id:one');
      expect(first.entries.single.size, 6000000000);
      expect(first.nextOffset, 1);
      final second = await source.browse(
        const BrowseRequest(offset: 1, limit: 1),
        context,
      );
      expect(second.entries.single.ref.id, 'id:folder');
      final third = await source.browse(
        const BrowseRequest(offset: 2, limit: 1),
        context,
      );
      expect(third.entries.single.name, '终集.mp4');
      expect(third.nextOffset, isNull);
      await source.dispose();
    },
  );

  test(
    'OneDrive pins personal drive identity and rejects foreign next links',
    () async {
      final client = Client((r) {
        if (r.uri.path == '/v1.0/me/drive') {
          return Response(200, {'id': 'drive!1', 'driveType': 'personal'});
        }
        if (r.uri.path.endsWith('/children')) {
          return Response(200, {
            'value': [
              {
                'id': 'file!1',
                'name': '电影.mp4',
                'file': {},
                'size': 5,
                'parentReference': {'driveId': 'drive!1', 'id': 'root!1'},
              },
            ],
            '@odata.nextLink': 'https://attacker.invalid/stolen',
          });
        }
        return Response(200, {'id': 'root!1', 'name': 'root', 'folder': {}});
      });
      final source = OneDriveSource(
        config(SourceKind.onedrive),
        session(SourceKind.onedrive),
        client: client,
      );
      final page = await source.browse(const BrowseRequest(limit: 1), context);
      expect(
        page.entries.single.ref.id,
        OneDriveSource.identity('drive!1', 'file!1'),
      );
      await expectLater(
        source.browse(const BrowseRequest(offset: 1, limit: 1), context),
        throwsA(isA<PluginException>()),
      );
      expect(
        client.requests.any((r) => r.uri.host == 'attacker.invalid'),
        isFalse,
      );
      expect(client.requests.any((r) => r.uri.path.contains('%21')), isFalse);
      await source.dispose();
    },
  );

  test('selected-root enforcement rejects moved files and cross-instance references', () async {
    final client = Client((r) {
      final id = (jsonDecode(r.body.toString()) as Map)['path'];
      return Response(200, {
        '.tag': id == 'id:file' ? 'file' : 'folder',
        'id': id,
        'name': id,
        'path_lower': id == 'id:file'
            ? '/outside/movie.mp4'
            : id == '/outside'
            ? '/outside'
            : '/selected',
      });
    });
    final source = DropboxSource(
      config(SourceKind.dropbox, root: 'id:root'),
      session(SourceKind.dropbox),
      client: client,
    );
    await expectLater(
      source.resolve(
        const ResolveRequest(ResourceRef('account-a', 'id:file')),
        context,
      ),
      throwsA(
        isA<PluginException>().having(
          (e) => e.code,
          'code',
          'permissionDenied',
        ),
      ),
    );
    await expectLater(
      source.browse(
        const BrowseRequest(node: ResourceRef('account-b', 'id:root')),
        context,
      ),
      throwsA(isA<PluginException>()),
    );
    await source.dispose();
  });

  test('429 respects backoff and disposal interrupts pending retry', () async {
    var requests = 0;
    final client = Client((r) {
      requests++;
      return Response(429, {}, headers: {'retry-after': '20'});
    });
    final source = DropboxSource(
      config(SourceKind.dropbox),
      session(SourceKind.dropbox),
      client: client,
    );
    final pending = source.browse(const BrowseRequest(), context);
    final assertion = expectLater(
      pending,
      throwsA(
        isA<PluginException>().having((e) => e.code, 'code', 'cancelled'),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await source.dispose();
    await assertion;
    expect(requests, 1);
    expect(client.closed, isTrue);
  });

  test('loopback playback renews expired links, preserves Range and never sends bearer to CDN', () async {
    var links = 0;
    final client = Client((r) {
      if (r.uri.host == 'api.dropboxapi.com') {
        expect(r.headers.value('authorization'), 'Bearer access');
        if (r.uri.path.endsWith('get_temporary_link')) {
          return Response(200, {'link': 'https://cdn.example/${++links}'});
        }
        final id = (jsonDecode(r.body.toString()) as Map)['path'];
        return Response(200, {
          '.tag': 'file',
          'id': id,
          'name': 'movie.mp4',
          'path_lower': '/movie.mp4',
          'size': 6000000000,
        });
      }
      expect(r.followRedirects, isFalse);
      expect(r.headers.value('authorization'), isNull);
      expect(r.headers.value('range'), 'bytes=4294967296-4294967298');
      if (r.uri.path == '/1') return Response(403, {});
      if (r.uri.host == 'cdn.example') {
        return Response(
          302,
          {},
          headers: {'location': 'https://other.example/final'},
        );
      }
      return Response(
        206,
        [7, 8, 9],
        raw: true,
        headers: {
          'content-range': 'bytes 4294967296-4294967298/6000000000',
          'content-length': '3',
        },
      );
    });
    final source = DropboxSource(
      config(SourceKind.dropbox),
      session(SourceKind.dropbox),
      client: client,
    );
    final stream = await source.resolve(
      const ResolveRequest(ResourceRef('account-a', 'id:movie')),
      context,
    );
    expect(stream.uri.host, '127.0.0.1');
    expect(stream.uri.toString(), isNot(contains('cdn')));
    final reader = HttpClient();
    final request = await reader.getUrl(stream.uri);
    request.headers.set('Range', 'bytes=4294967296-4294967298');
    final response = await request.close();
    expect(response.statusCode, 206);
    expect(await response.expand((c) => c).toList(), [7, 8, 9]);
    expect(links, 2);
    final head = await reader.openUrl('HEAD', stream.uri);
    head.headers.set('Range', 'bytes=4294967296-4294967298');
    final headResponse = await head.close();
    expect(headResponse.statusCode, 206);
    expect(
      headResponse.headers.value('content-range'),
      'bytes 4294967296-4294967298/6000000000',
    );
    await headResponse.drain<void>();
    expect(links, 3);
    reader.close(force: true);
    await stream.release();
    await source.dispose();
  });
}
