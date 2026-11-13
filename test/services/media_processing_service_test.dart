// Uses the real in-process bridge built by
// ../ffmpeg-package/tool/build_host_lib.sh (skipped when absent).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/services/ai_tools/media_processing_tools.dart';
import 'package:openplayx/services/ai_tools/media_tools.dart';
import 'package:openplayx/services/ai_tools/tool_registry.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/services/media_processing/media_processing_service.dart';
import 'package:openplayx_ffmpeg/openplayx_ffmpeg.dart';
import 'package:sqlite3/sqlite3.dart';

class _Sources extends SourceManager {
  Uri? remote;
  @override
  List<SourceConfig> get configs => [
    SourceConfig(
      id: 's1',
      name: 'Jelly',
      kind: SourceKind.jellyfin,
      address: 'https://private.test/',
    ),
  ];
  @override
  Future<void> load() async {}
  @override
  Future<PlayableStream> resolve(ResourceRef resource) async =>
      PlayableStream(remote!);
}

void main() {
  final ext = Platform.isMacOS ? 'dylib' : 'so';
  final lib = File('../ffmpeg-package/build/host/libopenplayx_ffmpeg.$ext')
      .absolute
      .path;
  final skip = File(lib).existsSync() ? null : 'build the host FFmpeg bridge';
  final video = File('test/fixtures/test_video.mp4').absolute.path;
  late Directory root;
  late LibraryService library;
  late MediaProcessingService service;
  late _Sources sources;

  setUp(() {
    root = Directory.systemTemp.createTempSync('opx_mp');
    library = LibraryService(sqlite3.openInMemory());
    sources = _Sources();
    service = MediaProcessingService(
      db: library.db,
      sources: sources,
      root: Future.value(root),
      processor: MediaProcessor(
        libraryPath: lib,
        pollInterval: const Duration(milliseconds: 20),
      ),
    );
  });
  tearDown(() {
    service.dispose();
    library.close();
    root.deleteSync(recursive: true);
  });

  Future<Map<String, dynamic>> settle(String id) async {
    for (var i = 0; i < 500; i++) {
      final t = service.task(id)!;
      if (const [
        'succeeded',
        'failed',
        'cancelled',
        'interrupted',
      ].contains(t['status'])) {
        return t;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('task did not settle');
  }

  test('all agent tools fit the registry without truncation', () {
    final tools = MediaTools(
      library: library,
      sources: sources,
      context: () => {},
      playbackSnapshot: () => {},
      playbackControl: (_, _) async => {},
      openResource: (_) async => {},
    );
    MediaProcessingTools(
      registry: tools.registry,
      service: service,
      library: library,
      sources: sources,
      entryForReference: tools.entryForReference,
    );
    for (final name in [
      'media_processing_capabilities',
      'media_probe',
      'media_transcode',
      'media_extract_audio',
      'media_snapshot',
      'task_get',
      'task_list',
      'task_cancel',
      'task_retry',
    ]) {
      expect(tools.registry[name], isNotNull, reason: name);
    }
    expect(tools.registry['ffmpeg_execute'], isNull);
    expect(tools.registry['run_command'], isNull);
  });

  test(
    'agent flow: probe → transcode task → artifact, without paths',
    () async {
      final resource = library.register(
        SourceEntry(ResourceRef('@local', video), 'Clip', isFolder: false),
      );
      final resourceId = library.resources(resource).single['id'] as String;
      final registry = ToolRegistry();
      MediaProcessingTools(
        registry: registry,
        service: service,
        library: library,
        sources: sources,
        entryForReference: (_) => null,
      );
      final gateway = ToolGateway(registry);
      final allowed = {
        for (final n in [
          'media_processing_capabilities',
          'media_probe',
          'media_transcode',
          'media_snapshot',
          'task_get',
          'task_cancel',
          'task_retry',
        ])
          n,
      };
      var n = 0;
      Future<ToolResult> call(String name, Map<String, dynamic> args) =>
          gateway.invoke(
            turn: 't',
            call: ModelToolCall('c${n++}', name, jsonEncode(args)),
            allowed: allowed,
            active: () => true,
            confirm: (_, _) async => true,
          );

      final caps = await call('media_processing_capabilities', {
        'resource_ref': resourceId,
      });
      expect(caps.status, 'success', reason: caps.error);
      final presets = caps.data['presets'] as List;
      expect(
        presets.any(
          (p) =>
              p['preset_id'] == 'video.mobile.720p' && p['available'] == true,
        ),
        isTrue,
      );

      final probe = await call('media_probe', {'resource_ref': resourceId});
      expect(probe.status, 'success', reason: probe.error);
      final track = (probe.data['tracks'] as List).first;
      expect(track['track_ref'], startsWith('track-'));
      expect(jsonEncode(probe.data), isNot(contains(video)));

      final submitted = await call('media_transcode', {
        'resource_ref': resourceId,
        'preset_id': 'video.mobile.720p',
        'preset_revision': 1,
      });
      expect(submitted.status, 'success', reason: submitted.error);
      final taskId = submitted.data['task_id'] as String;
      // Duplicate call in the same intent returns the same task.
      final again = await call('media_transcode', {
        'resource_ref': resourceId,
        'preset_id': 'video.mobile.720p',
        'preset_revision': 1,
      });
      expect(again.data['task_id'], taskId);

      final done = await settle(taskId);
      expect(done['status'], 'succeeded', reason: '$done');
      final artifact = done['artifact'] as Map<String, dynamic>;
      expect(artifact['kind'], 'video');
      expect(jsonEncode(done), isNot(contains(root.path)));
      final path = service.artifactPath(artifact['artifact_ref'] as String)!;
      expect(File(path).existsSync(), isTrue);
      expect(File(video).existsSync(), isTrue); // input untouched

      final stale = await call('media_transcode', {
        'resource_ref': resourceId,
        'preset_id': 'video.mobile.720p',
        'preset_revision': 2,
      });
      expect(stale.error, 'presetIncompatible:preset_revision_changed');

      final badTrack = await call('media_transcode', {
        'resource_ref': resourceId,
        'preset_id': 'video.remux.mp4',
        'preset_revision': 1,
        'audio_track_ref': 'track-forged',
      });
      expect(badTrack.error, 'staleReference');

      final outside = await call('media_snapshot', {
        'resource_ref': resourceId,
        'preset_id': 'image.preview',
        'preset_revision': 1,
        'time_ms': 86400000,
      });
      expect(outside.status, 'success');
      final failed = await settle(outside.data['task_id'] as String);
      expect(failed['status'], 'failed');
      expect(failed['error_code'], 'invalidArgument');

      final retried = await call('task_retry', {'task_id': failed['task_id']});
      expect(retried.status, 'success');
      expect(retried.data['attempt_of'], failed['task_id']);
      await settle(retried.data['task_id'] as String);
    },
    skip: skip,
  );

  test('remote URLs are refused, loopback session streams accepted', () async {
    const ref = ResourceRef('s1', '/film.mp4');
    sources.remote = Uri.parse('https://cdn.example.com/film.mp4');
    await expectLater(
      service.probe(ref),
      throwsA(
        isA<MediaException>().having(
          (e) => e.reason,
          'reason',
          'remote_stream_requires_download',
        ),
      ),
    );
    final bytes = File(video).readAsBytesSync();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final range = RegExp(r'bytes=(\d+)-(\d*)')
          .firstMatch(req.headers.value('range') ?? '');
      var start = 0, end = bytes.length - 1;
      if (range != null) {
        start = int.parse(range[1]!);
        if (range[2]!.isNotEmpty) end = int.parse(range[2]!);
        req.response.statusCode = 206;
        req.response.headers.set(
          'content-range',
          'bytes $start-$end/${bytes.length}',
        );
      }
      req.response.contentLength = end - start + 1;
      req.response.add(bytes.sublist(start, end + 1));
      await req.response.close();
    });
    addTearDown(() => server.close(force: true));
    sources.remote = Uri.parse('http://127.0.0.1:${server.port}/k/film.mp4');
    final probe = await service.probe(ref);
    expect(probe.primaryVideo, isNotNull);
  }, skip: skip);

  test(
    'debug snapshot picks 20%-80% and deletes its image on dispose',
    () async {
      final snap = service.debugSnapshot(
        ResourceRef('@local', video),
        random: Random(7),
      );
      final r = await snap.result;
      final ratio = r.time.inMicroseconds / r.duration.inMicroseconds;
      expect(ratio, inInclusiveRange(0.2, 0.8));
      expect(r.file.existsSync(), isTrue);
      await snap.dispose();
      expect(r.file.existsSync(), isFalse);
    },
    skip: skip,
  );

  test('recover marks unfinished tasks interrupted and compensates', () async {
    final db = library.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    db.execute(
      '''INSERT INTO processing_tasks (id,operation,preset_id,preset_revision,
       resource_source,resource_item,resource_name,params,state,output,created,updated)
       VALUES ('task-a','transcode','video.remux.mp4',1,'@local','/x','X','{}','running',NULL,?,?)''',
      [now, now],
    );
    final dir = Directory('${root.path}/artifacts')..createSync();
    final orphan = File('${dir.path}/task-b.mp4')..writeAsStringSync('data');
    File('${dir.path}/task-c.mp4.part').writeAsStringSync('partial');
    db.execute(
      '''INSERT INTO processing_tasks (id,operation,preset_id,preset_revision,
       resource_source,resource_item,resource_name,params,state,output,created,updated)
       VALUES ('task-b','transcode','video.remux.mp4',1,'@local','/x','X','{}','finalizing',?,?,?)''',
      [orphan.path, now, now],
    );
    await service.recover();
    expect(service.task('task-a')!['status'], 'interrupted');
    final b = service.task('task-b')!;
    expect(b['status'], 'succeeded');
    expect(b['artifact'], isNotNull);
    expect(File('${dir.path}/task-c.mp4.part').existsSync(), isFalse);
  });
}
