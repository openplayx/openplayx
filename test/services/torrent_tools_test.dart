import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/services/ai_tools/tool_registry.dart';
import 'package:openplayx/services/ai_tools/torrent_tools.dart';
import 'package:openplayx/services/torrent/torrent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const hash = '0123456789abcdef0123456789abcdef01234567';

/// Minimal stand-in for bittorrent-server's /v1 API.
class FakeServer {
  late HttpServer server;
  final requests = <String>[];
  final bodies = <Map<String, dynamic>>[];
  String state = 'downloading';

  String get url => 'http://127.0.0.1:${server.port}';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final raw = await utf8.decoder.bind(req).join();
      final body = raw.isEmpty || !raw.startsWith('{')
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      requests.add('${req.method} ${req.uri.path}');
      bodies.add(body);
      Object? out;
      var status = 200;
      if (req.headers.value('authorization') != 'Bearer good-token') {
        status = 401;
        out = {
          'error': {
            'code': 'unauthorized',
            'request_id': 'r',
            'retryable': false,
          },
        };
      } else {
        final task = {
          'id': 'tsk_1',
          'name': 'Show',
          'state': state,
          'progress': 0.5,
          'selected_size': 100,
          'total_size': 120,
          'download_speed': 2048,
          'upload_speed': 0,
          'metadata_known': true,
          'selected_files_complete': false,
          'payload_complete': false,
          'seeding': false,
          'added_via': 'app',
        };
        final webuiTask = {
          ...task,
          'id': 'b' * 40,
          'name': 'WebUI item',
          'added_via': 'other',
        };
        switch ('${req.method} ${req.uri.path}') {
          case 'GET /api/v1/capabilities':
            out = {
              'engine': {'available': true, 'version': 'v5.1.0'},
              'inputs': ['magnet', 'torrent_file'],
              'destinations': [
                {'destination_ref': 'default', 'name': 'Downloads'},
              ],
            };
          case 'POST /api/v1/torrent-plans':
            out = {
              'plan_ref': 'plan_server_secret',
              'name': 'Show',
              'input_kind': 'magnet',
              'metadata': 'unknown',
              'warnings': ['metadata_unknown'],
            };
            status = 201;
          case 'POST /api/v1/torrents':
            out = task;
            status = 201;
          case 'GET /api/v1/torrents':
            out = {
              'items': [task, webuiTask],
            };
          case 'GET /api/v1/torrents/tsk_1':
            out = task;
          case 'GET /api/v1/torrents/tsk_1/files':
            out = {
              'metadata_known': true,
              'files_revision': 'rev1',
              'files': [
                {
                  'file_id': 'f0',
                  'path': 'Show/a.mkv',
                  'size': 100,
                  'selected': true,
                  'complete': false,
                },
                {
                  'file_id': 'f1',
                  'path': 'Show/b.txt',
                  'size': 20,
                  'selected': true,
                  'complete': false,
                },
              ],
            };
          case 'PATCH /api/v1/torrents/tsk_1/selection':
            out = {
              'metadata_known': true,
              'files_revision': 'rev2',
              'files': [
                {'file_id': 'f0', 'selected': true},
                {'file_id': 'f1', 'selected': false},
              ],
            };
          case 'POST /api/v1/torrents/tsk_1/pause':
            state = 'paused';
            out = {...task, 'state': 'paused'};
          case 'POST /api/v1/torrents/tsk_1/remove-plan':
            out = {
              'plan_ref': 'rmp_1',
              'task_name': 'Show',
              'delete_files': body['delete_files'],
              'files_on_disk': 2,
              'bytes_on_disk': 3 << 20,
              'effects': ['engine_task_removed'],
            };
            status = 201;
          case 'POST /api/v1/torrents/tsk_1/remove':
            out = {'task_id': 'tsk_1', 'removed': true, 'data_deleted': false};
          default:
            status = 404;
            out = {
              'error': {
                'code': 'not_found',
                'request_id': 'r',
                'retryable': false,
              },
            };
        }
      }
      req.response.statusCode = status;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(out));
      await req.response.close();
    });
  }
}

Future<ToolResult> call(
  ToolGateway gateway,
  String name,
  Map<String, dynamic> args, {
  bool approve = true,
  List<String>? confirmed,
}) => gateway.invoke(
  turn: 't-${DateTime.now().microsecondsSinceEpoch}',
  call: ModelToolCall('c-$name', name, jsonEncode(args)),
  allowed: {name},
  active: () => true,
  confirm: (tool, _) async {
    confirmed?.add(tool);
    return approve;
  },
);

void main() {
  late FakeServer fake;
  late TorrentServiceStore store;
  late ToolRegistry registry;
  late TorrentTools tools;
  late ToolGateway gateway;
  var userTexts = <String>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    fake = FakeServer();
    await fake.start();
    store = TorrentServiceStore();
    await store.load();
    registry = ToolRegistry();
    userTexts = [];
    tools = TorrentTools(
      registry: registry,
      store: store,
      userTexts: () => userTexts,
    );
    gateway = ToolGateway(registry);
  });

  tearDown(() => fake.server.close(force: true));

  test('URL policy: HTTPS anywhere, HTTP only on private hosts', () {
    expect(TorrentServiceConfig.validateUrl('https://bt.example.com'), isNull);
    expect(
      TorrentServiceConfig.validateUrl('http://192.168.1.20:18780'),
      isNull,
    );
    expect(TorrentServiceConfig.validateUrl('http://127.0.0.1:1'), isNull);
    expect(
      TorrentServiceConfig.validateUrl('http://bt.example.com'),
      isNotNull,
    );
    expect(
      TorrentServiceConfig.validateUrl('https://u:p@bt.example.com'),
      isNotNull,
    );
    expect(
      TorrentServiceConfig.validateUrl('https://bt.example.com/api?x=1'),
      isNotNull,
    );
  });

  test('tools are offered only once a server is configured', () async {
    expect(
      registry.available.where((t) => t.name.startsWith('torrent_')),
      isEmpty,
    );
    await store.save(
      TorrentServiceConfig(id: 'bt-1', name: 'Home', baseUrl: fake.url),
      token: 'good-token',
    );
    final names = registry.available
        .map((t) => t.name)
        .where((n) => n.startsWith('torrent_'));
    expect(names, hasLength(12));
    // No tool accepts a URL, token or server path parameter.
    for (final t in registry.available.where(
      (t) => t.name.startsWith('torrent_'),
    )) {
      final props = (t.schema['properties'] as Map).keys;
      expect(
        props.any(
          (p) => [
            'url',
            'base_url',
            'token',
            'save_path',
            'savepath',
            'path',
          ].contains(p),
        ),
        isFalse,
      );
    }
  });

  group('with a configured server', () {
    setUp(() async {
      await store.save(
        TorrentServiceConfig(id: 'bt-1', name: 'Home', baseUrl: fake.url),
        token: 'good-token',
      );
    });

    test('magnet must come from the user; plan_ref is host-issued', () async {
      const magnet = 'magnet:?xt=urn:btih:$hash&dn=Show';
      var r = await call(gateway, 'torrent_plan', {'magnet': magnet});
      expect(r.error, 'magnetNotFromUser');
      expect(fake.requests, isEmpty);
      userTexts = ['请下载 $magnet'];
      r = await call(gateway, 'torrent_plan', {'magnet': magnet});
      expect(r.status, 'success', reason: '${r.toJson()}');
      expect(r.data['plan_ref'], isNot('plan_server_secret'));
      final add = await call(gateway, 'torrent_add', {
        'plan_ref': r.data['plan_ref'],
      });
      expect(add.status, 'success', reason: '${add.toJson()}');
      final task = add.data['task'] as Map;
      expect(task['location'], 'server');
      expect(task['in_app_library'], false);
      expect(task['server_name'], 'Home');
      final createBody =
          fake.bodies[fake.requests.indexOf('POST /api/v1/torrents')];
      expect(createBody, {'plan_ref': 'plan_server_secret'});
      final encoded = jsonEncode([r.data, add.data]);
      expect(encoded.contains(fake.url), isFalse);
      expect(encoded.contains('good-token'), isFalse);
    });

    test('list is live, includes WebUI torrents, and maps task_refs', () async {
      final a = await call(gateway, 'torrent_list', {});
      final b = await call(gateway, 'torrent_list', {});
      // No client-side caching: every query reaches the server.
      expect(
        fake.requests.where((r) => r == 'GET /api/v1/torrents'),
        hasLength(2),
      );
      final tasks = a.data['torrent_tasks'] as List;
      expect(tasks.map((t) => t['added_via']), ['app', 'other']);
      final ref = tasks.first['task_ref'];
      expect(tasks.last['task_ref'], isNot(ref));
      expect((b.data['torrent_tasks'] as List).first['task_ref'], ref);
      final paused = await call(gateway, 'torrent_pause', {'task_ref': ref});
      expect((paused.data['torrent_task'] as Map)['state'], 'paused');
      expect(
        (await call(gateway, 'torrent_get', {'task_ref': 'task-forged'})).error,
        'staleReference',
      );
    });

    test(
      'selection and removal need host refs and user confirmation',
      () async {
        final ref =
            ((await call(gateway, 'torrent_list', {})).data['torrent_tasks']
                    as List)
                .first['task_ref'];
        final files = await call(gateway, 'torrent_files', {'task_ref': ref});
        final fileRef =
            (files.data['files'] as List).first['file_ref'] as String;
        final confirmed = <String>[];
        final sel = await call(gateway, 'torrent_select_files', {
          'task_ref': ref,
          'file_ref': fileRef,
          'action': 'only',
        }, confirmed: confirmed);
        expect(sel.status, 'success', reason: '${sel.toJson()}');
        expect(confirmed, ['torrent_select_files']);
        expect(
          fake.bodies[fake.requests.indexOf(
            'PATCH /api/v1/torrents/tsk_1/selection',
          )]['file_ids'],
          ['f0'],
        );

        // Deleting data is outside the configured access scope.
        final denied = await call(gateway, 'torrent_remove_preview', {
          'task_ref': ref,
          'delete_files': true,
        });
        expect(denied.error, 'deleteFilesNotAllowed');
        final preview = await call(gateway, 'torrent_remove_preview', {
          'task_ref': ref,
        });
        final removal = preview.data['removal_ref'] as String;
        expect(
          tools.describe('torrent_remove', {'removal_ref': removal}),
          contains('保留已下载文件'),
        );
        final cancelled = await call(gateway, 'torrent_remove', {
          'removal_ref': removal,
        }, approve: false);
        expect(cancelled.status, 'cancelled');
        expect(
          fake.requests.contains('POST /api/v1/torrents/tsk_1/remove'),
          isFalse,
        );
        final removed = await call(gateway, 'torrent_remove', {
          'removal_ref': removal,
        }, confirmed: confirmed);
        expect(removed.status, 'success');
        expect(
          fake.bodies[fake.requests.indexOf(
            'POST /api/v1/torrents/tsk_1/remove',
          )]['plan_ref'],
          'rmp_1',
        );
      },
    );

    test(
      'unreachable server reports an error without dropping config',
      () async {
        await fake.server.close(force: true);
        final r = await call(gateway, 'torrent_list', {});
        expect(r.status, 'success');
        expect(
          (r.data['server_errors'] as List).single['error_code'],
          'serviceUnreachable',
        );
        expect(store.configs, hasLength(1));
      },
    );

    test('bad token surfaces unauthorized', () async {
      await store.save(store.config('bt-1')!, token: 'bad');
      final r = await call(gateway, 'torrent_service_info', {});
      expect((r.data['servers'] as List).single['error_code'], 'unauthorized');
    });
  });

  // Full chain against a real bittorrent-server + qbittorrent-nox stack:
  //   TORRENT_E2E_URL=http://127.0.0.1:28780 TORRENT_E2E_TOKEN=... TORRENT_E2E_TORRENT=/path/x.torrent
  test(
    'real server: upload → plan → add → progress → pause → remove',
    () async {
      final env = Platform.environment;
      await store.save(
        TorrentServiceConfig(
          id: 'bt-real',
          name: 'E2E',
          baseUrl: env['TORRENT_E2E_URL']!,
          pollSeconds: 5,
        ),
        token: env['TORRENT_E2E_TOKEN'],
      );
      final client = await store.client('bt-real');
      final input = await client.uploadTorrent(
        Uint8List.fromList(File(env['TORRENT_E2E_TORRENT']!).readAsBytesSync()),
      );
      final upload = tools.registerUpload('bt-real', input);
      final info = await call(gateway, 'torrent_service_info', {});
      expect(
        (info.data['uploaded_inputs'] as List).single['input_ref'],
        upload,
      );
      expect((info.data['servers'] as List).single['available'], true);
      final plan = await call(gateway, 'torrent_plan', {'input_ref': upload});
      expect(plan.status, 'success', reason: '${plan.toJson()}');
      final add = await call(gateway, 'torrent_add', {
        'plan_ref': plan.data['plan_ref'],
      });
      expect(add.status, 'success', reason: '${add.toJson()}');
      final ref = (add.data['task'] ?? add.data)['task_ref'] as String;
      // TORRENT_E2E_NO_PEERS=1: a deployed instance without reachable
      // fixture peers; only the control path is checked.
      final noPeers = env['TORRENT_E2E_NO_PEERS'] == '1';
      Map task = {};
      for (var i = 0; i < 60; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        task =
            (await call(gateway, 'torrent_get', {
                  'task_ref': ref,
                })).data['torrent_task']
                as Map;
        if (noPeers
            ? task['metadata_known'] == true &&
                  ['downloading', 'stalled'].contains(task['state'])
            : task['selected_files_complete'] == true) {
          break;
        }
      }
      if (noPeers) {
        expect(task['state'], anyOf('downloading', 'stalled'), reason: '$task');
        expect(task['selected_files_complete'], false);
        final resumed = await call(gateway, 'torrent_pause', {'task_ref': ref});
        expect(resumed.status, 'success', reason: '${resumed.toJson()}');
        final again = await call(gateway, 'torrent_resume', {'task_ref': ref});
        expect(again.status, 'success', reason: '${again.toJson()}');
        final limits = await call(gateway, 'torrent_set_limits', {
          'task_ref': ref,
          'download_kib': 512,
          'upload_kib': 128,
        });
        expect(limits.status, 'success', reason: '${limits.toJson()}');
        final denied = await call(gateway, 'torrent_remove_preview', {
          'task_ref': ref,
          'delete_files': true,
        });
        expect(denied.error, 'deleteFilesNotAllowed');
        userTexts = ['magnet:?xt=urn:btih:$hash&tr=http://192.168.1.5:9000/a'];
        final private = await call(gateway, 'torrent_plan', {
          'magnet': userTexts.single,
        });
        expect(private.error, 'network_address_not_allowed');
      } else {
        expect(task['selected_files_complete'], true, reason: '$task');
      }
      expect(task['in_app_library'], false);
      final paused = await call(gateway, 'torrent_pause', {'task_ref': ref});
      expect(paused.status, 'success', reason: '${paused.toJson()}');
      final preview = await call(gateway, 'torrent_remove_preview', {
        'task_ref': ref,
      });
      final removed = await call(gateway, 'torrent_remove', {
        'removal_ref': preview.data['removal_ref'],
      });
      expect(removed.status, 'success', reason: '${removed.toJson()}');
    },
    skip: Platform.environment['TORRENT_E2E_URL'] == null
        ? 'set TORRENT_E2E_URL to run'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
