import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/assistant/plugins/library/media_tools.dart';
import 'package:openplayx/assistant/plugins/media_processing/media_processing_tools.dart';
import 'package:openplayx/assistant/plugins/tools/tool_registry.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/media_processing/media_processing_service.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fake_media_processor.dart';

class _TestSources extends SourceManager {
  Uri? streamUri;
  SourceEntry? writtenEntry;
  bool writeThrows = false;
  bool resolveThrows = false;

  @override
  List<SourceConfig> get configs => [
    SourceConfig(
      id: 's1',
      name: 'NAS',
      kind: SourceKind.smb,
      address: 'smb://nas.local/movies',
    ),
  ];

  @override
  Future<void> load() async {}

  @override
  Future<PlayableStream> resolve(ResourceRef resource) async {
    if (resolveThrows) throw Exception('offline');
    return PlayableStream(streamUri!);
  }

  @override
  Future<SourceEntry> writeNewFile(
    ResourceRef near,
    String fileName,
    File source, {
    String? folder,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (writeThrows) throw const PluginException('disk_full', 'disk full');
    writtenEntry = SourceEntry(
      ResourceRef(near.instanceId, '/OpenPlayX/$fileName'),
      fileName,
      isFolder: false,
    );
    return writtenEntry!;
  }
}

void main() {
  late Directory root;
  late File sampleFile;
  late LibraryService library;
  late _TestSources sources;
  late FakeMediaProcessor processor;
  late MediaProcessingService service;

  setUp(() {
    root = Directory.systemTemp.createTempSync('opx_mp_unit_');
    sampleFile = File('${root.path}/movie.mp4')..writeAsBytesSync([1, 2, 3, 4]);
    library = LibraryService(sqlite3.openInMemory());
    sources = _TestSources();
    processor = FakeMediaProcessor();
    service = MediaProcessingService(
      db: library.db,
      sources: sources,
      root: Future.value(Directory('${root.path}/mp')),
      processor: processor,
    );
  });

  tearDown(() {
    service.dispose();
    library.close();
    root.deleteSync(recursive: true);
  });

  Future<Map<String, dynamic>> waitDone(String id) async {
    for (var i = 0; i < 100; i++) {
      final t = service.task(id)!;
      if (const [
        'succeeded',
        'failed',
        'cancelled',
        'interrupted',
      ].contains(t['status'])) {
        return t;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('task $id did not finish');
  }

  test('probe, transcode, artifact publishing, taskOutput and deleteArtifact', () async {
    final ref = ResourceRef('@local', sampleFile.path);
    final probe = await service.probe(ref);
    expect(probe.duration, const Duration(seconds: 120));

    final created = service.submit(
      ref: ref,
      resourceName: 'Test Movie.mp4',
      presetId: MediaPreset.mobile720p.id,
      presetRevision: MediaPreset.mobile720p.revision,
      operation: MediaOperation.transcode,
      request: const PlanRequest(
        start: Duration(seconds: 10),
        end: Duration(seconds: 25),
      ),
    );
    final done = await waitDone(created['task_id'] as String);
    expect(done['status'], 'succeeded');
    final artifact = done['artifact'] as Map<String, dynamic>;
    final artifactId = artifact['artifact_ref'] as String;
    expect(artifact['kind'], 'video');
    expect(service.artifactPath(artifactId), isNotNull);
    expect(File(service.artifactPath(artifactId)!).existsSync(), isTrue);

    final out = service.taskOutput(created['task_id'] as String)!;
    expect(out.startMs, 10000);
    expect(out.endMs, 25000);
    expect(service.tasks(), hasLength(1));

    await service.deleteArtifact(artifactId);
    expect(service.artifactPath(artifactId), isNull);
  });

  test('submit validates preset, revision, availability and quota', () async {
    final ref = ResourceRef('@local', sampleFile.path);
    expect(
      () => service.submit(
        ref: ref,
        resourceName: 'm.mp4',
        presetId: 'nope',
        presetRevision: 1,
        operation: MediaOperation.transcode,
      ),
      throwsA(isA<MediaException>()),
    );
    expect(
      () => service.submit(
        ref: ref,
        resourceName: 'm.mp4',
        presetId: MediaPreset.mobile720p.id,
        presetRevision: 999,
        operation: MediaOperation.transcode,
      ),
      throwsA(
        isA<MediaException>().having(
          (e) => e.code,
          'code',
          MediaErrorCode.presetIncompatible,
        ),
      ),
    );

    processor.isAvailable = false;
    expect(
      () => service.submit(
        ref: ref,
        resourceName: 'm.mp4',
        presetId: MediaPreset.mobile720p.id,
        presetRevision: MediaPreset.mobile720p.revision,
        operation: MediaOperation.transcode,
      ),
      throwsA(
        isA<MediaException>().having(
          (e) => e.code,
          'code',
          MediaErrorCode.unavailable,
        ),
      ),
    );
    processor.isAvailable = true;

    final tinyQuota = MediaProcessingService(
      db: library.db,
      sources: sources,
      root: Future.value(Directory('${root.path}/mp')),
      processor: processor,
      quotaBytes: 0,
    );
    expect(
      () => tinyQuota.submit(
        ref: ref,
        resourceName: 'm.mp4',
        presetId: MediaPreset.mobile720p.id,
        presetRevision: MediaPreset.mobile720p.revision,
        operation: MediaOperation.transcode,
      ),
      throwsA(
        isA<MediaException>().having(
          (e) => e.code,
          'code',
          MediaErrorCode.noSpace,
        ),
      ),
    );
    tinyQuota.dispose();
  });

  test('cancel, retry, dedup active task, and failure handling', () async {
    final ref = ResourceRef('@local', sampleFile.path);
    final hold = Completer<void>();
    processor.holdNextJob = hold;
    final t1 = service.submit(
      ref: ref,
      resourceName: 'm.mp4',
      presetId: MediaPreset.speechWav.id,
      presetRevision: MediaPreset.speechWav.revision,
      operation: MediaOperation.extractAudio,
    );
    // Duplicate active request returns the same task id.
    final t2 = service.submit(
      ref: ref,
      resourceName: 'm.mp4',
      presetId: MediaPreset.speechWav.id,
      presetRevision: MediaPreset.speechWav.revision,
      operation: MediaOperation.extractAudio,
    );
    expect(t2['task_id'], t1['task_id']);

    // Let t1 reach processor.submit so it consumes holdNextJob.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final cancelling = service.cancel(t1['task_id'] as String);
    expect(cancelling['status'], 'cancelling');
    final cancelled = await waitDone(t1['task_id'] as String);
    expect(cancelled['status'], 'cancelled');

    // Retry creates a new attempt linked via attempt_of.
    final retried = service.retry(t1['task_id'] as String);
    expect(retried['attempt_of'], t1['task_id']);
    final done = await waitDone(retried['task_id'] as String);
    expect(done['status'], 'succeeded');
    // Cancelling already-terminal task is a no-op.
    expect(service.cancel(retried['task_id'] as String)['status'], 'succeeded');
    // Retrying succeeded task throws.
    expect(
      () => service.retry(retried['task_id'] as String),
      throwsA(isA<MediaException>()),
    );
    expect(() => service.cancel('missing'), throwsA(isA<MediaException>()));
    expect(() => service.retry('missing'), throwsA(isA<MediaException>()));
  });

  test('remote URL rejected, loopback accepted, videoCover & debugSnapshot work', () async {
    sources.streamUri = Uri.parse('https://remote.example/video.mp4');
    await expectLater(
      service.probe(const ResourceRef('s1', '/video.mp4')),
      throwsA(
        isA<MediaException>().having(
          (e) => e.code,
          'code',
          MediaErrorCode.accessDenied,
        ),
      ),
    );

    sources.streamUri = Uri.parse('http://127.0.0.1:9999/stream');
    final p = await service.probe(const ResourceRef('s1', '/video.mp4'));
    expect(p.duration, const Duration(seconds: 120));

    final bytes = await MediaProcessingService.videoCover(
      sources,
      ResourceRef('@local', sampleFile.path),
      processor: processor,
    );
    expect(bytes, isNotEmpty);

    final snap = service.debugSnapshot(
      ResourceRef('@local', sampleFile.path),
      random: Random(1),
    );
    final snapResult = await snap.result;
    expect(snapResult.file.existsSync(), isTrue);
    await snap.dispose();
    expect(snapResult.file.existsSync(), isFalse);
  });

  test('MediaProcessingTools executes all tools and enforces permissions', () async {
    final mediaTools = MediaTools(
      library: library,
      sources: sources,
      context: () => {},
      playbackSnapshot: () => {},
      playbackControl: (_, _) async => {},
      openResource: (_) async => {},
    );
    sources.streamUri = Uri.parse('http://127.0.0.1:9999/stream');
    final entries = <String, SourceEntry>{
      'ref-local': SourceEntry(
        ResourceRef('@local', sampleFile.path),
        'movie.mp4',
        isFolder: false,
      ),
      'ref-nas': SourceEntry(
        const ResourceRef('s1', '/movie.mp4'),
        'movie.mp4',
        isFolder: false,
      ),
    };
    MediaProcessingTools(
      registry: mediaTools.registry,
      service: service,
      library: library,
      sources: sources,
      entryForReference: (r) => entries[r],
      issueReference: (e) => {'ref': 'issued:${e.name}'},
    );

    Future<Map<String, dynamic>> call(String name, Map<String, dynamic> args) =>
        ToolExecution.run(
          () => mediaTools.registry[name]!.execute(args),
          () => true,
        );

    final caps = await call('media_processing_capabilities', {
      'resource_ref': 'ref-local',
    });
    expect(caps['available'], isTrue);
    expect(caps['presets'], isNotEmpty);

    final probe = await call('media_probe', {'resource_ref': 'ref-nas'});
    final tracks = probe['tracks'] as List;
    final audioRef = tracks
        .cast<Map<String, dynamic>>()
        .firstWhere((t) => t['type'] == 'audio')['track_ref'] as String;

    final transcode = await call('media_transcode', {
      'resource_ref': 'ref-nas',
      'preset_id': MediaPreset.mobile720p.id,
      'preset_revision': MediaPreset.mobile720p.revision,
      'start_ms': 0,
      'end_ms': 10000,
      'audio_track_ref': audioRef,
      'wait_seconds': 5,
    });
    expect(transcode['status'], 'succeeded');

    final saved = await call('media_save_to_source', {
      'task_id': transcode['task_id'],
    });
    expect(saved['saved'], isTrue);
    expect(sources.writtenEntry, isNotNull);

    final audio = await call('media_extract_audio', {
      'resource_ref': 'ref-local',
      'preset_id': MediaPreset.speechWav.id,
      'preset_revision': MediaPreset.speechWav.revision,
      'wait_seconds': 5,
    });
    expect(audio['status'], 'succeeded');

    final snap = await call('media_snapshot', {
      'resource_ref': 'ref-local',
      'time_ms': 5000,
      'preset_id': MediaPreset.imagePreview.id,
      'preset_revision': MediaPreset.imagePreview.revision,
    });
    final got = await call('task_get', {
      'task_id': snap['task_id'],
      'wait_seconds': 5,
    });
    expect(got['status'], 'succeeded');

    final listed = await call('task_list', {'offset': 0, 'limit': 10});
    expect((listed['tasks'] as List).length, greaterThanOrEqualTo(3));

    expect(
      MediaProcessingTools.clipName('dir/Movie: 1.mp4', 0, 65000, 'mp4'),
      'Movie_ 1 [clip 00m00s-01m05s].mp4',
    );
    expect(
      MediaProcessingTools.clipName('.hidden', 3661000, null, 'mp4'),
      'clip.hidden [clip 1h01m01s-end].mp4',
    );

    // Invalid ref & local save-to-source failure paths
    await expectLater(
      call('media_probe', {'resource_ref': 'bad-ref'}),
      throwsA(isA<ToolFailure>()),
    );
    await expectLater(
      call('media_save_to_source', {'task_id': audio['task_id']}),
      throwsA(isA<ToolFailure>()),
    );
  });
}
