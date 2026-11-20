import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/sources/baidu_source.dart';
import 'package:openplayx/data/sources/cloud_oauth.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:openplayx/features/sources/controller/source_form_controller.dart';

import 'cloud_sources_test.dart'
    show Client, Response, MemorySecrets, config, session, tokens, context;

Map<String, dynamic> file(int id, String path, {bool folder = false}) => {
  'fs_id': id,
  'path': path,
  'server_filename': path.split('/').last,
  'isdir': folder ? 1 : 0,
  'size': folder ? 0 : 6000000000,
};
Matcher error(String code) =>
    throwsA(isA<PluginException>().having((e) => e.code, 'code', code));

class OAuthClient extends Client {
  OAuthClient(super.handler);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
}

void main() {
  test(
    'Baidu uses configured HTTPS publisher bridge and verifies callback',
    () {
      final app = CloudOAuthApp(
        SourceKind.baidu,
        clientId: 'own-app',
        broker: Uri.parse('https://api.example/v1/oauth/baidu'),
      );
      expect(app.configured, isTrue);
      expect(
        app.authorize.toString(),
        'https://api.example/v1/oauth/baidu/authorize',
      );
      expect(app.token.toString(), 'https://api.example/v1/oauth/baidu/token');
      final attempt = CloudOAuthAttempt(app);
      expect(attempt.loginUri.queryParameters['scope'], 'basic,netdisk');
      expect(attempt.loginUri.queryParameters['code_challenge_method'], 'S256');
      expect(
        attempt.code(
          app.redirect.replace(
            queryParameters: {'state': attempt.state, 'code': 'ticket'},
          ),
        ),
        'ticket',
      );
      expect(
        () => attempt.code(
          app.redirect.replace(
            queryParameters: {'state': 'wrong', 'code': 'ticket'},
          ),
        ),
        error('authRequired'),
      );
      expect(
        CloudOAuthApp(
          SourceKind.baidu,
          clientId: 'own-app',
          broker: Uri.parse('http://unsafe.example'),
        ).configured,
        isFalse,
      );
      expect(
        CloudOAuthApp(
          SourceKind.baidu,
          clientId: 'own-app',
          broker: Uri.parse('https://user:password@example'),
        ).configured,
        isFalse,
      );
    },
  );

  test('OAuth bridge exchanges only public fields and distinguishes network/auth errors', () async {
    final app = CloudOAuthApp(
      SourceKind.baidu,
      clientId: 'own-app',
      broker: Uri.parse('https://api.example/v1/oauth/baidu'),
    );
    for (final status in [200, 400, 502, 503]) {
      final client = OAuthClient((r) {
        expect(r.uri, app.token);
        expect(r.followRedirects, isFalse);
        final fields = Uri.splitQueryString(r.body.toString());
        expect(fields['client_id'], 'own-app');
        expect(fields.containsKey('client_secret'), isFalse);
        expect(fields['refresh_token'], 'previous-refresh');
        return Response(status, {
          'access_token': 'new',
          'refresh_token': 'rotated',
          'expires_in': 3600,
        });
      });
      await HttpOverrides.runZoned(() async {
        final pending = CloudOAuth.exchange(app, {
          'grant_type': 'refresh_token',
          'refresh_token': 'previous-refresh',
        });
        if (status == 200) {
          expect((await pending).refreshToken, 'rotated');
        } else {
          await expectLater(
            pending,
            error(
              status == 400
                  ? 'authRequired'
                  : status == 503
                  ? 'unsupported'
                  : 'networkUnavailable',
            ),
          );
        }
        expect(client.closed, isTrue);
      }, createHttpClient: (_) => client);
    }
  });

  test('editing a selected directory can select all files and save without reauthorizing', () async {
    final client = Client(
      (r) => Response(200, {
        'errno': 0,
        'list': [file(1, '/Movies', folder: true)],
      }),
    );
    await HttpOverrides.runZoned(() async {
      final db = SourceConfigurationService(sqlite3.openInMemory());
      final manager = SourceManager(
        configuration: db,
        secureStore: MemorySecrets(),
      );
      SourceFormController? form;
      try {
        await manager.save(
          config(SourceKind.baidu, root: '1'),
          tokens().encode(),
        );
        form = SourceFormController(
          manager: manager,
          initial: manager.configs.single,
          onFailure: (message) => fail(message),
        );
        await form.selectAllCloudFiles();
        expect(form.cloudFolderName, '/');
        expect(form.cloudFolders.single.name, 'Movies');
        expect(form.cloudCanBack, isFalse);
        expect(await form.save(), isTrue);
        expect(manager.configs.single.cloudRootId, 'root');
        expect(await manager.storedSecret('account-a'), isNotNull);
      } finally {
        form?.dispose();
        await manager.dispose();
        db.close();
      }
    }, createHttpClient: (_) => client);
  });

  test(
    'root pages use start/limit and preserve fs_id, Unicode and large sizes',
    () async {
      final client = Client((r) {
        expect(r.followRedirects, isFalse);
        expect(r.uri.queryParameters['access_token'], 'access');
        expect(r.headers.value('authorization'), isNull);
        final p = r.uri.queryParameters;
        expect(p['dir'], '/');
        expect(p['limit'], '200');
        return Response(200, {
          'errno': 0,
          'list': p['start'] == '0'
              ? List.generate(200, (i) => file(i + 1, '/电影 $i.mkv'))
              : [file(201, '/终集.mp4')],
        });
      });
      final source = BaiduSource(
        config(SourceKind.baidu),
        session(SourceKind.baidu),
        client: client,
      );
      final first = await source.browse(
        const BrowseRequest(limit: 200),
        context,
      );
      expect(first.entries.first.ref.id, '1');
      expect(first.entries.first.size, 6000000000);
      expect(first.nextOffset, 200);
      final next = await source.browse(
        const BrowseRequest(offset: 200, limit: 200),
        context,
      );
      expect(next.entries.single.name, '终集.mp4');
      expect(next.nextOffset, isNull);
      await source.dispose();
    },
  );

  test(
    'selected root rechecks current paths and rejects forged or moved refs',
    () async {
      final client = Client((r) {
        final id =
            (jsonDecode(r.uri.queryParameters['fsids']!) as List).single as int;
        return Response(200, {
          'errno': 0,
          'list': [
            file(
              id,
              id == 1 ? '/Movies' : '/Movies-other/moved.mp4',
              folder: id == 1,
            ),
          ],
        });
      });
      final source = BaiduSource(
        config(SourceKind.baidu, root: '1'),
        session(SourceKind.baidu),
        client: client,
      );
      await expectLater(
        source.resolve(
          const ResolveRequest(ResourceRef('account-a', '2')),
          context,
        ),
        error('permissionDenied'),
      );
      await expectLater(
        source.metadata('/Movies/film.mp4'),
        error('permissionDenied'),
      );
      await expectLater(
        source.browse(
          const BrowseRequest(node: ResourceRef('other-account', '1')),
          context,
        ),
        error('permissionDenied'),
      );
      await source.dispose();
    },
  );

  test('HTTP-200 expired token refreshes once, persists rotation, then asks to sign in', () async {
    var refreshes = 0, saves = 0;
    final s = CloudTokenSession(
      SourceKind.baidu,
      tokens(),
      refresh: (_) async {
        refreshes++;
        return tokens('rotated');
      },
      persist: (_) async {
        saves++;
      },
    );
    final client = Client((_) => Response(200, {'errno': 20017}));
    final source = BaiduSource(config(SourceKind.baidu), s, client: client);
    await expectLater(
      source.browse(const BrowseRequest(), context),
      error('authRequired'),
    );
    expect(refreshes, 1);
    expect(saves, 1);
    expect(client.requests.last.uri.queryParameters['access_token'], 'rotated');
    await source.dispose();
  });

  test('network, account denial, throttling and malformed JSON give typed feedback', () async {
    for (final (response, code) in [
      (Response(403, {}), 'permissionDenied'),
      (Response(200, {'errno': -6}), 'permissionDenied'),
      (Response(200, {'errno': 31034}), 'rateLimited'),
      (Response(503, {}), 'networkUnavailable'),
      (Response(200, utf8.encode('not json'), raw: true), 'networkUnavailable'),
    ]) {
      final source = BaiduSource(
        config(SourceKind.baidu),
        session(SourceKind.baidu),
        client: Client((_) => response),
      );
      await expectLater(
        source.browse(const BrowseRequest(), context),
        error(code),
      );
      await source.dispose();
    }
    for (final failure in [
      const SocketException('offline'),
      TimeoutException('timeout'),
    ]) {
      final source = BaiduSource(
        config(SourceKind.baidu),
        session(SourceKind.baidu),
        client: Client((_) => throw failure),
      );
      await expectLater(
        source.browse(const BrowseRequest(), context),
        error('networkUnavailable'),
      );
      await source.dispose();
    }
  });

  test('scan feeds existing library; restart retains OS credentials and disconnect erases them', () async {
    final client = Client((r) {
      final p = r.uri.queryParameters;
      if (p['method'] == 'filemetas') {
        return Response(200, {
          'errno': 0,
          'list': [file(1, '/Movies', folder: true)],
        });
      }
      return Response(200, {
        'errno': 0,
        'list': p['dir'] == '/'
            ? [file(1, '/Movies', folder: true)]
            : [file(2, '/Movies/电影.mp4'), file(3, '/Movies/notes.txt')],
      });
    });
    await HttpOverrides.runZoned(() async {
      final db = SourceConfigurationService(sqlite3.openInMemory());
      final store = MemorySecrets();
      var manager = SourceManager(configuration: db, secureStore: store);
      final library = LibraryService(sqlite3.openInMemory());
      try {
        await manager.save(config(SourceKind.baidu), tokens().encode());
        expect(db.readSecret('account-a'), startsWith('secure-source:'));
        expect(
          jsonEncode(manager.configs.single.toJson()),
          isNot(contains('refresh')),
        );
        await manager.dispose();
        manager = SourceManager(configuration: db, secureStore: store);
        await manager.load();
        final binding = library.addFileSource('account-a', name: 'Baidu');
        await library.scan(binding, manager);
        expect(
          library.resourceFor(const ResourceRef('account-a', '2')),
          isNotNull,
        );
        expect(
          library.resourceFor(const ResourceRef('account-a', '3')),
          isNull,
        );
        final shared = await manager.cloudTokenSession(manager.configs.single);
        await manager.remove('account-a');
        expect(shared.isClosed, isTrue);
        expect(store.values, isEmpty);
      } finally {
        await manager.dispose();
        library.close();
        db.close();
      }
    }, createHttpClient: (_) => client);
  });

  test('download retries stale links, forwards Range/UA and rejects credential redirects', () async {
    var links = 0;
    var malicious = false;
    final client = Client((r) {
      if (r.uri.host == 'pan.baidu.com') {
        final link = r.uri.queryParameters['dlink'] == '1';
        return Response(200, {
          'errno': 0,
          'list': [
            {
              ...file(2, '/电影.mp4'),
              if (link) 'dlink': 'https://d.pcs.baidu.com/file/${++links}',
            },
          ],
        });
      }
      expect(r.headers.value('authorization'), isNull);
      expect(r.headers.value('user-agent'), contains('pan.baidu.com'));
      expect(r.headers.value('range'), 'bytes=4294967296-4294967298');
      expect(r.followRedirects, isFalse);
      if (malicious) {
        return Response(
          302,
          {},
          headers: {'location': 'https://attacker.invalid/leak'},
        );
      }
      if (links == 1) return Response(403, {});
      return Response(206, [1, 2, 3], raw: true);
    });
    final source = BaiduSource(
      config(SourceKind.baidu),
      session(SourceKind.baidu),
      client: client,
    );
    final response = await source.content(
      'GET',
      '2',
      range: 'bytes=4294967296-4294967298',
    );
    expect(await response.expand((e) => e).toList(), [1, 2, 3]);
    expect(links, 2);
    expect(
      client.requests
          .where((r) => r.uri.host == 'd.pcs.baidu.com')
          .first
          .uri
          .queryParameters['access_token'],
      'access',
    );
    malicious = true;
    await expectLater(
      source.content('HEAD', '2', range: 'bytes=4294967296-4294967298'),
      error('permissionDenied'),
    );
    expect(
      client.requests.any((r) => r.uri.host == 'attacker.invalid'),
      isFalse,
    );
    await source.dispose();
  });

  test(
    'resolved Baidu media plays through existing loopback gateway',
    () async {
      final client = Client((r) {
        if (r.uri.host == 'pan.baidu.com') {
          return Response(200, {
            'errno': 0,
            'list': [
              {
                ...file(2, '/movie.mp4'),
                'dlink': 'https://d.pcs.baidu.com/file/2',
              },
            ],
          });
        }
        expect(r.headers.value('authorization'), isNull);
        expect(r.headers.value('user-agent'), contains('pan.baidu.com'));
        return Response(
          206,
          [7],
          raw: true,
          headers: {
            'content-range': 'bytes 0-0/6000000000',
            'content-length': '1',
          },
        );
      });
      final source = BaiduSource(
        config(SourceKind.baidu),
        session(SourceKind.baidu),
        client: client,
      );
      final stream = await source.resolve(
        const ResolveRequest(ResourceRef('account-a', '2')),
        context,
      );
      final reader = HttpClient();
      try {
        expect(stream.uri.host, '127.0.0.1');
        expect(stream.uri.toString(), isNot(contains('access_token')));
        final request = await reader.getUrl(stream.uri);
        request.headers.set('Range', 'bytes=0-0');
        final response = await request.close();
        expect(response.statusCode, 206);
        expect(response.headers.value('content-range'), 'bytes 0-0/6000000000');
        expect(await response.expand((bytes) => bytes).toList(), [7]);
      } finally {
        reader.close(force: true);
        await stream.release();
        await source.dispose();
      }
    },
  );

  test(
    'missing dlink and persistent download denial fail before player launch',
    () async {
      for (final missing in [true, false]) {
        final client = Client((r) {
          if (r.uri.host == 'pan.baidu.com') {
            return Response(200, {
              'errno': 0,
              'list': [
                {
                  ...file(2, '/film.mp4'),
                  if (!missing) 'dlink': 'https://d.pcs.baidu.com/file/2',
                },
              ],
            });
          }
          return Response(403, {});
        });
        final source = BaiduSource(
          config(SourceKind.baidu),
          session(SourceKind.baidu),
          client: client,
        );
        await expectLater(
          source.resolve(
            const ResolveRequest(ResourceRef('account-a', '2')),
            context,
          ),
          error('permissionDenied'),
        );
        await source.dispose();
      }
    },
  );
}
