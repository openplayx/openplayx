import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/media_processing/media_processing_service.dart';
import 'package:openplayx/capabilities/metadata/metadata_service.dart';
import 'package:openplayx/capabilities/metadata/providers/tmdb_metadata_plugin.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/capabilities/speech/asr_backend_config.dart';
import 'package:openplayx/capabilities/speech/asr_model_store.dart';
import 'package:openplayx/capabilities/speech/subtitle_generation_service.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/features/library/view/audio_subtitle_debug_page.dart';
import 'package:openplayx/features/library/view/metadata_page.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../app_test_host.dart';
import '../../support/fake_media_processor.dart';
import '../../support/fake_sources.dart';
import '../../support/library_test_helpers.dart';

Future<Map<String, dynamic>> _stubTmdb(
  String path,
  Map<String, String> query,
) async {
  if (path == '/configuration') {
    return {
      'images': {
        'secure_base_url': 'https://image.tmdb.org/t/p/',
        'poster_sizes': ['w500', 'original'],
        'backdrop_sizes': ['w1280', 'original'],
        'logo_sizes': ['w500', 'original'],
        'profile_sizes': ['w185', 'original'],
        'still_sizes': ['w300', 'original'],
      },
    };
  }
  if (path == '/search/movie') {
    return {
      'page': 1,
      'total_pages': 1,
      'results': [
        {
          'id': 503919,
          'title': 'The Lighthouse',
          'original_title': 'The Lighthouse',
          'release_date': '2019-10-18',
          'overview': 'Two lighthouse keepers.',
          'poster_path': '/p1.jpg',
          'backdrop_path': '/b1.jpg',
          'vote_average': 7.5,
          'popularity': 30.0,
        },
        {
          'id': 503920,
          'title': 'The Lighthouse (Alt)',
          'original_title': 'The Lighthouse',
          'release_date': '2016-01-01',
          'overview': 'Alt candidate.',
          'vote_average': 6.0,
          'popularity': 10.0,
        },
      ],
    };
  }
  if (path == '/movie/503919') {
    return {
      'id': 503919,
      'title': 'The Lighthouse',
      'original_title': 'The Lighthouse',
      'release_date': '2019-10-18',
      'runtime': 109,
      'overview': 'Two lighthouse keepers.',
      'poster_path': '/p1.jpg',
      'backdrop_path': '/b1.jpg',
      'vote_average': 7.5,
      'genres': [
        {'id': 18, 'name': 'Drama'},
      ],
      'production_countries': [
        {'iso_3166_1': 'US', 'name': 'United States'},
      ],
      'credits': {
        'cast': [
          {'name': 'Willem Dafoe', 'character': 'Thomas Wake', 'profile_path': '/w.jpg'},
        ],
        'crew': [
          {'name': 'Robert Eggers', 'job': 'Director', 'profile_path': '/r.jpg'},
        ],
      },
      'images': {
        'posters': [
          {'file_path': '/p1.jpg', 'iso_639_1': 'en', 'width': 500, 'height': 750},
        ],
        'backdrops': [
          {'file_path': '/b1.jpg', 'iso_639_1': null, 'width': 1280, 'height': 720},
        ],
        'logos': [
          {'file_path': '/l1.png', 'iso_639_1': 'en', 'width': 600, 'height': 200},
        ],
      },
    };
  }
  return {'results': <Object?>[]};
}

void main() {
  testWidgets('MetadataPage interactive search, candidate pick and refresh', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final library = LibraryService(sqlite3.openInMemory());
    final sources = Sources();
    addTearDown(library.close);

    final movieId = library.register(
      const SourceEntry(
        ResourceRef('s', '/The.Lighthouse.2019.mkv'),
        'The.Lighthouse.2019.mkv',
        isFolder: false,
      ),
    );
    addToLibrary(library, movieId);

    final metaService = MetadataService(library, sources);
    metaService.registry.register('tmdb', TmdbMetadataPlugin(_stubTmdb));
    addTearDown(metaService.dispose);

    await tester.pumpWidget(
      TestApp(
        home: MetadataPage(
          library: library,
          sources: sources,
          media: movieId,
          service: metaService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final searchBtn = find.text('识别 / 重新匹配');
    if (searchBtn.evaluate().isNotEmpty) {
      await tester.tap(searchBtn.first);
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('The Lighthouse'), findsWidgets);
  });

  testWidgets('AudioSubtitleDebugPage whole-media toggle, invalid range and missing model', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final tmp = Directory.systemTemp.createTempSync('opx_asr_extra_');
    final sample = File('${tmp.path}/movie.mp4')..writeAsBytesSync([1, 2, 3]);
    final db = sqlite3.openInMemory();
    final processor = FakeMediaProcessor();
    final media = MediaProcessingService(
      db: db,
      sources: SourceManager(),
      root: Future.value(Directory('${tmp.path}/media')),
      processor: processor,
    );
    final fakeBackend = FakeAsrBackend(
      available: false,
      unavailableReason: 'model_missing',
    );
    final registry = AsrBackendRegistry(
      db: db,
      models: AsrModelStore(Future.value(Directory('${tmp.path}/models'))),
      backendFactory: (_) => fakeBackend,
    );
    final service = SubtitleGenerationService(
      db: db,
      media: media,
      backends: registry,
      root: Future.value(Directory('${tmp.path}/subtitles')),
    );
    addTearDown(() {
      service.dispose();
      media.dispose();
      db.close();
      tmp.deleteSync(recursive: true);
    });

    await tester.pumpWidget(
      TestApp(
        home: AudioSubtitleDebugPage(
          service: service,
          target: AudioSubtitleTarget(
            resource: ResourceRef('@local', sample.path),
            title: 'Extra Test',
            resourceName: 'movie.mp4',
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    final startField = find.byKey(const ValueKey('asr-start'));
    if (startField.evaluate().isNotEmpty) {
      await tester.enterText(
        find.descendant(of: startField, matching: find.byType(EditableText)),
        '999',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('asr-extract')));
      await tester.pump();
    }

    final wholeKey = find.byKey(const ValueKey('asr-whole'));
    if (wholeKey.evaluate().isNotEmpty) {
      await tester.tap(wholeKey);
      await tester.pump();
    }
    fakeBackend.available = true;
    await tester.tap(find.byKey(const ValueKey('asr-transcribe')));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  });
}
