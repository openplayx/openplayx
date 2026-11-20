// Prints sanitized stage results for this explicitly invoked live diagnostic.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/app/debug_seed/seed_template.dart';
import 'package:openplayx/capabilities/artwork/artwork_service.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/metadata/metadata_queue_runner.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/core/capabilities/metadata_capability.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx_ffmpeg/src/native.dart';

import '../../test/metadata/video_cover_fallback_test.dart' show EmptyCatalog;
import '../../test/support/library_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // This diagnostic deliberately uses real HTTP; Flutter's widget-test
  // default HttpClient otherwise synthesizes status 400 for every request.
  HttpOverrides.global = null;
  final env = <String, String>{
    if (File('../design/.env').existsSync())
      ...parseEnv(File('../design/.env').readAsStringSync()),
    ...Platform.environment,
  };

  test('real Dart SMB artwork and automatic metadata pipeline', () async {
    MediaNative.libraryPath = File(
      env['COVER_PROBE_FFMPEG_LIBRARY'] ??
          '../ffmpeg-package/build/host/libopenplayx_ffmpeg.dylib',
    ).absolute.path;
    final prefix = ['COVER_PROBE', 'COVER_PROBE_2'].firstWhere(
      (p) =>
          (env['${p}_MEDIA_PATH'] ?? '').toLowerCase().contains('test_video'),
    );
    final configuration = SourceConfigurationService(sqlite3.openInMemory());
    final config = configuration.save(
      SourceConfig(
        id: 'pipeline-smb',
        kind: SourceKind.smb,
        name: 'Diagnostic SMB',
        address: env['${prefix}_SMB_ADDRESS']!,
        username: env['${prefix}_SMB_USER'] ?? '',
      ),
      expectedRevision: 0,
      secret: env['${prefix}_SMB_PASSWORD'] ?? '',
    );
    final sources = SourceManager(configuration: configuration);
    final root = await Directory.systemTemp.createTemp('opx-cover-pipeline-');
    final artwork = ArtworkService(sources, directory: root);
    addTearDown(() async {
      artwork.dispose();
      await sources.dispose();
      configuration.close();
      await root.delete(recursive: true);
    });
    await sources.load();
    final path = env['${prefix}_MEDIA_PATH']!;
    final ref = ResourceRef(config.id, path);
    final cover = await artwork.load(
      ArtworkDescriptor(
        id: '${ArtworkService.videoCoverPrefix}direct-test',
        type: 'poster',
        source: ref,
      ),
    );
    final codec = await ui.instantiateImageCodec(await cover.readAsBytes());
    final image = (await codec.getNextFrame()).image;
    print(
      'DART ARTWORK: ${await cover.length()} bytes, decoded ${image.width}x${image.height}',
    );
    image.dispose();
    codec.dispose();

    for (final live in [true, false]) {
      final library = LibraryService(
        sqlite3.openInMemory(),
        watchExternalChanges: false,
      );
      final media = library.register(
        SourceEntry(ref, path.split('/').last, isFolder: false),
      );
      addToLibrary(library, media);
      final workerArtwork = ArtworkService(sources, directory: root);
      final worker = MetadataQueueRunner(
        library,
        sources,
        artwork: workerArtwork,
        credentials: () async => env['TMDB_READ_ACCESS_TOKEN'],
        registry: live
            ? null
            : (MetadataRegistry()..register('tmdb', EmptyCatalog())),
      );
      try {
        await worker.reconcile();
        await worker.runBatch();
        final row = worker.queue.item(media)!;
        final selected = library.metadata.displayArtwork(media);
        final job = library.metadata.latestJob(media);
        print(
          '${live ? 'LIVE TMDB' : 'EMPTY CATALOG CONTROL'}: '
          'state=${row['state']}, error=${row['error_code']}, '
          'cover=${selected != null}, stage=${job?['stage']}',
        );
        if (selected != null) {
          final file = await workerArtwork.load(selected);
          print('PUBLISHED ARTWORK: ${await file.length()} bytes');
        }
        expect(selected, isNotNull);
      } finally {
        await worker.dispose();
        library.close();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
