import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/assistant/plugins/external/external_file_transfer.dart';
import 'package:openplayx/assistant/plugins/external/external_service_registry.dart';
import 'package:openplayx/assistant/plugins/plugin_access.dart';
import 'package:openplayx/assistant/plugins/tools/tool_registry.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:sqlite3/sqlite3.dart';

ExternalService service(String base, {String? endpoint}) => ExternalService(
  id: 'video',
  name: 'Video',
  baseUrl: base,
  endpoint: endpoint ?? '$base/mcp',
  serverName: 'yt-dlp',
  available: true,
);

class _Access implements PluginAccess {
  bool allow = true;
  @override
  bool pluginEnabled(String id) => allow;
  @override
  bool aiAllows(String id, {String? instanceId, String? capability}) => allow;
}

class _Sources extends SourceManager {
  final bytes = <int>[];
  bool? usedCache;
  String? folder;
  void Function()? beforeWrite;
  @override
  List<SourceConfig> get configs => const [
    SourceConfig(
      id: 'nas',
      name: 'NAS',
      kind: SourceKind.smb,
      address: 'smb://nas/movie',
    ),
  ];
  @override
  Future<void> load() async {}
  @override
  Future<SourceEntry> writeNewStream(
    String instanceId,
    String name,
    Stream<List<int>> stream,
    int length, {
    String? folder,
    File? cachedFile,
    SourceWriteCancellation? cancellation,
  }) async {
    beforeWrite?.call();
    this.folder = folder;
    usedCache = cachedFile != null;
    await for (final chunk in stream) {
      cancellation?.check();
      bytes.addAll(chunk);
    }
    expect(bytes.length, length);
    return SourceEntry(
      ResourceRef(instanceId, '/movie/$name'),
      name,
      isFolder: false,
    );
  }
}

void main() {
  test(
    'file paths are host built, keep proxy prefix and reject URL injection',
    () {
      expect(
        ExternalFileDownload.fileUri(
          service('https://video.test/proxy'),
          'abc123',
          0,
        ).toString(),
        'https://video.test/proxy/files/abc123/0',
      );
      for (final job in [
        '../x',
        'https://private.test',
        '//127.0.0.1',
        'x?url=y',
        'x%2f..',
      ]) {
        expect(
          () => ExternalFileDownload.fileUri(
            service('https://video.test'),
            job,
            0,
          ),
          throwsA(isA<ToolFailure>()),
        );
      }
      expect(
        () => ExternalFileDownload.fileUri(
          service('https://video.test', endpoint: 'https://other.test/mcp'),
          'abc',
          0,
        ),
        throwsA(isA<ToolFailure>()),
      );
    },
  );

  late HttpServer server;
  late ExternalService remote;
  final body = utf8.encode('video content');
  late List<String?> ranges;
  late List<String?> tokens;
  late String behavior;
  setUp(() async {
    ranges = [];
    tokens = [];
    behavior = 'normal';
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    remote = service('http://127.0.0.1:${server.port}/proxy');
    server.listen((request) async {
      final response = request.response;
      tokens.add(request.headers.value('authorization'));
      if (behavior == 'redirect') {
        response.statusCode = 302;
        response.headers.set('location', 'http://127.0.0.1:1/private');
      } else if (behavior == 'denied') {
        response.statusCode = 403;
      } else if (behavior == 'dropOnce' &&
          request.method == 'GET' &&
          ranges.isEmpty) {
        ranges.add(request.headers.value('range'));
        final socket = await response.detachSocket(writeHeaders: false);
        socket.add(
          utf8.encode(
            'HTTP/1.1 200 OK\r\nContent-Length: ${body.length}\r\nETag: "video"\r\nConnection: close\r\n\r\n',
          ),
        );
        socket.add(body.sublist(0, 5));
        await socket.flush();
        await socket.close();
        return;
      } else {
        response.headers.set(
          'etag',
          behavior == 'changed' ? '"new"' : '"video"',
        );
        response.headers.set(
          'content-disposition',
          "attachment; filename*=UTF-8''%E8%A7%86%E9%A2%91.mp4",
        );
        response.contentLength = body.length;
        if (request.method == 'GET') {
          final range = request.headers.value('range');
          ranges.add(range);
          final offset = range == null
              ? 0
              : int.parse(range.substring(6, range.length - 1));
          if (offset > 0 && behavior != 'ignoreRange') {
            response.statusCode = 206;
            response.headers.set(
              'content-range',
              'bytes $offset-${body.length - 1}/${body.length}',
            );
            response.contentLength = body.length - offset;
            expect(request.headers.value('if-range'), '"video"');
          }
          response.add(body.sublist(behavior == 'ignoreRange' ? 0 : offset));
        }
      }
      await response.close();
    });
  });
  tearDown(() async {
    await server.close(force: true);
  });

  ExternalFileDownload download() => ExternalFileDownload(
    ExternalFileDownload.fileUri(remote, 'abc123', 0),
    'test-token',
  );

  test(
    'HEAD gets RFC 5987 metadata and Range resumes at the exact offset',
    () async {
      final d = download();
      addTearDown(d.cancel);
      final meta = await d.metadata();
      expect(meta.name, '视频.mp4');
      expect(meta.length, body.length);
      final bytes = await d
          .read(meta.length, meta.etag, offset: 5)
          .expand((v) => v)
          .toList();
      expect(bytes, body.sublist(5));
      expect(ranges, ['bytes=5-']);
      expect(tokens, everyElement('Bearer test-token'));
    },
  );

  test('changed content and servers ignoring Range cannot corrupt an existing prefix', () async {
    for (final mode in ['changed', 'ignoreRange']) {
      behavior = 'normal';
      final d = download();
      addTearDown(d.cancel);
      final meta = await d.metadata();
      behavior = mode;
      await expectLater(
        d.read(meta.length, meta.etag, offset: 5).drain<void>(),
        throwsA(
          isA<ToolFailure>().having(
            (e) => e.code,
            'code',
            'external_file_changed_or_range_unsupported',
          ),
        ),
      );
    }
  });

  test(
    'redirect is refused and read permission errors are actionable',
    () async {
      for (final mode in ['redirect', 'denied']) {
        behavior = mode;
        final d = download();
        addTearDown(d.cancel);
        await expectLater(
          d.metadata(),
          throwsA(
            isA<ToolFailure>().having(
              (e) => e.code,
              'code',
              mode == 'redirect'
                  ? 'external_redirect_rejected'
                  : 'external_read_permission_required',
            ),
          ),
        );
      }
    },
  );

  test(
    'broken HTTP read reconnects with Range without duplicating bytes',
    () async {
      behavior = 'dropOnce';
      final d = download();
      addTearDown(d.cancel);
      final meta = await d.metadata();
      final received = await d
          .read(meta.length, meta.etag)
          .expand((v) => v)
          .toList();
      expect(received, body);
      expect(ranges, [null, 'bytes=5-']);
    },
  );

  test(
    'cancelled HTTP transfer stops before opening another request',
    () async {
      final d = download();
      d.cancel();
      await expectLater(
        d.metadata(),
        throwsA(isA<ToolFailure>().having((e) => e.code, 'code', 'cancelled')),
      );
      expect(tokens, isEmpty);
    },
  );

  group('background transfers', () {
    late Database db;
    late ExternalServiceRegistry registry;
    late ExternalFileTransfers jobs;
    late _Sources sources;
    late _Access access;
    late Directory cache;
    setUp(() async {
      db = sqlite3.openInMemory();
      registry = ExternalServiceRegistry(db: db);
      await registry.save(remote, token: 'test-token');
      sources = _Sources();
      access = _Access();
      cache = await Directory.systemTemp.createTemp('external-transfer-test');
      jobs = ExternalFileTransfers(
        db: db,
        services: registry,
        sources: sources,
        access: access,
        cacheDirectory: () async => cache,
        availableBytes: () async => 2 * 1024 * 1024 * 1024,
      );
    });
    tearDown(() async {
      await jobs.dispose();
      await registry.changes.close();
      db.close();
      await cache.delete(recursive: true);
    });
    Map<String, dynamic> args(String mode) => {
      'service_id': 'video',
      'job_id': 'abc123',
      'file_index': 0,
      'target_instance_id': 'nas',
      'folder': '',
      'transfer_mode': mode,
    };
    Future<Map<String, dynamic>> finish(String id) async {
      if (!{
        'succeeded',
        'failed',
        'cancelled',
      }.contains(jobs.task(id)!['status'])) {
        await jobs.changes
            .firstWhere(
              (changed) =>
                  changed == id &&
                  {
                    'succeeded',
                    'failed',
                    'cancelled',
                  }.contains(jobs.task(id)!['status']),
            )
            .timeout(const Duration(seconds: 5));
      }
      return jobs.task(id)!;
    }

    test('stream and cache jobs write exact bytes, retain root target and clean cache', () async {
      for (final mode in ['stream', 'cache']) {
        sources.bytes.clear();
        final started = await jobs.submit(args(mode));
        final result = await finish(started['task_id'] as String);
        expect(result['status'], 'succeeded', reason: '$result');
        expect(sources.bytes, body);
        expect(sources.folder, '');
        expect(sources.usedCache, mode == 'cache');
        expect(cache.listSync(recursive: true).whereType<File>(), isEmpty);
      }
    });
    test('source.write must be allowed before any HTTP request', () async {
      access.allow = false;
      await expectLater(
        jobs.submit(args('stream')),
        throwsA(
          isA<ToolFailure>().having(
            (e) => e.code,
            'code',
            'permissionDenied:source.write',
          ),
        ),
      );
      expect(tokens, isEmpty);
    });
    test('permission revocation is checked again before writing', () async {
      sources.beforeWrite = () {
        access.allow = false;
      };
      final started = await jobs.submit(args('stream'));
      final result = await finish(started['task_id'] as String);
      expect(result['status'], 'failed');
      expect(result['error'], 'permissionDenied:source.write');
      expect(sources.bytes, isEmpty);
    });
    test(
      'cancelled background jobs stop and never publish a destination',
      () async {
        final started = await jobs.submit(args('stream'));
        final id = started['task_id'] as String;
        jobs.cancel(id);
        expect((await finish(id))['status'], 'cancelled');
        expect(sources.bytes, isEmpty);
      },
    );

    test(
      'same request attaches to existing task rather than duplicating a file',
      () async {
        final first = await jobs.submit(args('stream'));
        await finish(first['task_id'] as String);
        final second = await jobs.submit(args('stream'));
        expect(second['task_id'], first['task_id']);
        expect(ranges.length, 1);
      },
    );
    test(
      'interrupted cache resumes after restart and is removed on success',
      () async {
        final t = await jobs.submit(args('cache'));
        final id = t['task_id'] as String;
        await finish(id);
        await jobs.dispose();
        final data = Map<String, dynamic>.from(
          jsonDecode(
            db.select('SELECT data FROM external_file_tasks WHERE id=?', [
                  id,
                ]).single['data']
                as String,
          ) as Map,
        );
        data['status'] = 'running';
        data['_etag'] = '"video"';
        db.execute('UPDATE external_file_tasks SET data=? WHERE id=?', [
          jsonEncode(data),
          id,
        ]);
        final dir = Directory('${cache.path}/external_file_transfers');
        await dir.create(recursive: true);
        await File('${dir.path}/$id.part').writeAsBytes(body.sublist(0, 5));
        sources.bytes.clear();
        ranges.clear();
        jobs = ExternalFileTransfers(
          db: db,
          services: registry,
          sources: sources,
          cacheDirectory: () async => cache,
          availableBytes: () async => 2 * 1024 * 1024 * 1024,
        );
        expect(jobs.task(id)!['status'], 'interrupted');
        jobs.retry(id);
        expect((await finish(id))['status'], 'succeeded');
        expect(ranges, ['bytes=5-']);
        expect(sources.bytes, body);
        expect(dir.listSync(), isEmpty);
      },
    );

    test('cache space is checked before downloading the body', () async {
      await jobs.dispose();
      jobs = ExternalFileTransfers(
        db: db,
        services: registry,
        sources: sources,
        cacheDirectory: () async => cache,
        availableBytes: () async => 1,
      );
      final t = await jobs.submit(args('cache'));
      final result = await finish(t['task_id'] as String);
      expect(result['error'], 'insufficient_cache_space:use_stream');
      expect(ranges, isEmpty);
      expect(sources.bytes, isEmpty);
    });
  });
}
