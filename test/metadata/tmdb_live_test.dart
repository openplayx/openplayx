import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/app/theme/app_theme_controller.dart';
import 'package:openplayx/core/plugins/metadata_capability.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/features/library/library_page.dart';
import 'package:openplayx/features/library/metadata_page.dart';
import 'package:openplayx/plugins/metadata_tmdb/tmdb_metadata_plugin.dart';
import 'package:openplayx/services/artwork/artwork_service.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/services/metadata/metadata_service.dart';

import 'metadata_page_test.dart' show OfflineSources;

/// Explicitly opted-in live validation. Secrets are read only at runtime from
/// .env, never dart-define, assets, reports, screenshots or source-controlled data.
class _RealHttp extends HttpOverrides {}

void main() {
  const output = String.fromEnvironment('OPENPLAYX_TMDB_LIVE_DIR');
  testWidgets(
    'real TMDB search, movie/TV artwork, cache and application screenshots',
    (tester) async {
      final root = Directory(output);
      late LibraryService library;
      late MetadataService service;
      late ArtworkService artwork;
      late String firstMedia;
      final sources = OfflineSources();
      final movies = <String>[];
      final report = <String, dynamic>{
        'provider': 'TMDB',
        'language': 'zh-CN',
        'movies': <Map<String, dynamic>>[],
      };
      const screenshotsOnly = bool.fromEnvironment(
        'OPENPLAYX_TMDB_SCREENSHOTS_ONLY',
      );
      if (!screenshotsOnly) {
        await tester.runAsync(
          () => HttpOverrides.runWithHttpOverrides(() async {
            await root.create(recursive: true);
            final env = await File('.env').readAsLines();
            final token = env
                .where((line) => line.startsWith('TMDB_READ_ACCESS_TOKEN='))
                .map(
                  (line) =>
                      line.substring('TMDB_READ_ACCESS_TOKEN='.length).trim(),
                )
                .single;
            if (token.isEmpty) {
              throw StateError('Missing local TMDB read token');
            }
            final transport = TmdbTransport(token);
            library = LibraryService(sqlite3.openInMemory());
            service = MetadataService(library, sources);
            service.registry.register(
              'tmdb',
              TmdbMetadataPlugin(transport.get, onDispose: transport.close),
            );
            artwork = ArtworkService(
              sources,
              directory: Directory('${root.path}/artwork'),
              retainedArtwork: () => library.metadata.retainedArtwork,
            );
            final lib = library.create('TMDB 联调 · 真实影视资料', type: 'movie');
            Future<Map<String, dynamic>> verifyImage(
              ArtworkDescriptor descriptor,
            ) async {
              final file = await artwork.load(descriptor);
              final bytes = await file.readAsBytes();
              final codec = await ui.instantiateImageCodec(bytes);
              final frame = await codec.getNextFrame();
              final dimensions = {
                'width': frame.image.width,
                'height': frame.image.height,
              };
              expect(frame.image.width, greaterThan(50));
              expect(frame.image.height, greaterThan(50));
              frame.image.dispose();
              codec.dispose();
              return {
                'type': descriptor.type,
                'bytes': bytes.length,
                ...dimensions,
              };
            }

            for (final spec in [
              (query: 'Interstellar', year: 2014, id: '157336'),
              (query: 'Inception', year: 2010, id: '27205'),
              (query: 'Spirited Away', year: 2001, id: '129'),
              (query: 'Dune', year: 2021, id: '438631'),
              (query: 'The Dark Knight', year: 2008, id: '155'),
            ]) {
              final name = '${spec.query}.${spec.year}.mkv';
              final media = library.register(
                SourceEntry(
                  ResourceRef('@local', '/test-fixtures/$name'),
                  name,
                  isFolder: false,
                ),
              );
              library.addManual(lib, media);
              movies.add(media);
              final job = await service.search(
                media,
                query: spec.query,
                year: spec.year,
              );
              final candidates = (jsonDecode(
                service.repository.job(job)['candidates'] as String,
              ) as List).map((e) => MetadataRecord.fromJson(e));
              final match = candidates.firstWhere((c) => c.ref.id == spec.id);
              await service.confirm(job, match.ref);
              final fields = service.repository.fields(media);
              expect(fields['title'], isNotEmpty);
              expect(fields['overview'], isNotEmpty);
              final poster = service.repository.selectedArtwork(media)!;
              final backdrop = service.repository.selectedArtwork(
                media,
                type: 'backdrop',
              )!;
              final images = [
                await verifyImage(poster),
                await verifyImage(backdrop),
              ];
              (report['movies'] as List).add({
                'id': spec.id,
                'title': fields['title'],
                'year': fields['year'],
                'images': images,
              });
              debugPrint(
                'TMDB live: ${fields['title']} · poster/backdrop decoded',
              );
            }
            firstMedia = movies.first;
            // Real episode flow: search show -> season -> episode -> confirmed parents.
            final episode = library.register(
              const SourceEntry(
                ResourceRef('@local', '/test-fixtures/Breaking.Bad.S01E01.mkv'),
                'Breaking.Bad.S01E01.mkv',
                isFolder: false,
              ),
            );
            library.addManual(lib, episode);
            final job = await service.search(
              episode,
              query: 'Breaking Bad',
              kind: MediaKind.series,
              year: 2008,
            );
            MetadataRecord choose(bool Function(MetadataRecord) test) =>
                (jsonDecode(service.repository.job(job)['candidates'] as String)
                        as List)
                    .map((e) => MetadataRecord.fromJson(e))
                    .firstWhere(test);
            await service.children(job, choose((r) => r.ref.id == '1396').ref);
            await service.children(job, choose((r) => r.ref.season == 1).ref);
            final target = choose((r) => r.ref.episode == 1);
            await service.confirm(job, target.ref);
            final thumbnail = service.repository
                .artworkCandidates(episode)
                .firstWhere((a) => a.type == 'thumbnail');
            final episodeImage = await verifyImage(thumbnail);
            final parents = library.db.select(
              'SELECT parent_id FROM metadata_relations WHERE child_id=?',
              [episode],
            );
            expect(parents, hasLength(1));
            final show = library.query(lib, contentType: 'series').single;
            final seriesPoster = library.metadata.selectedArtwork(
              show['id'] as String,
            )!;
            await verifyImage(seriesPoster);
            report['episode'] = {
              'series': 'Breaking Bad',
              'season': 1,
              'episode': 1,
              'tmdbId': target.ref.id,
              'title': library.metadata.fields(episode)['title'],
              'image': episodeImage,
            };
            // Preload only the gallery page visible initially, with the real host loader.
            for (final image
                in library.metadata.artworkCandidates(firstMedia).take(12)) {
              await verifyImage(image);
            }
            final selected = library.metadata.selectedArtwork(firstMedia)!;
            library.transaction(
              () => library.metadata.selectArtwork(
                firstMedia,
                selected,
                expectedRevision: library.metadata.revision(firstMedia),
              ),
            );
            library.rename(firstMedia, '星际穿越');
            await service.refresh(firstMedia);
            expect(library.metadata.fields(firstMedia)['title'], '星际穿越');
            expect(
              library.metadata.selectedArtwork(firstMedia)!.id,
              selected.id,
            );
            report['locksSurvivedRefresh'] = true;
            report['verifiedAt'] = DateTime.now().toUtc().toIso8601String();
            final snapshot = File('${root.path}/library.sqlite3');
            if (await snapshot.exists()) await snapshot.delete();
            library.db.execute('VACUUM INTO ?', [snapshot.path]);
            await File(
              '${root.path}/report.json',
            ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
          }, _RealHttp()),
        );
      } else {
        library = LibraryService(sqlite3.open('${root.path}/library.sqlite3'));
        service = MetadataService(library, sources);
        artwork = ArtworkService(
          sources,
          directory: Directory('${root.path}/artwork'),
        );
        firstMedia =
            library.db
                    .select(
                      "SELECT media_id FROM resources WHERE name='Interstellar.2014.mkv'",
                    )
                    .single['media_id']
                as String;
      }
      debugPrint('TMDB live: data verified; loading fonts');
      addTearDown(() async {
        artwork.dispose();
        await service.dispose();
        library.close();
      });
      // Production UI now reads the cache populated by actual TMDB/CDN requests.
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pathChannel,
        (call) async => root.path,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          pathChannel,
          null,
        ),
      );
      await tester.runAsync(() async {
        final manifest = jsonDecode(
          await rootBundle.loadString('FontManifest.json'),
        ) as List;
        for (final entry in manifest) {
          final loader = FontLoader(entry['family'] as String);
          for (final font in entry['fonts'] as List) {
            loader.addFont(
              rootBundle.load(Uri.decodeFull(font['asset'] as String)),
            );
          }
          await loader.load();
        }
        final cjkFile = File(
          '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
        );
        if (await cjkFile.exists()) {
          final bytes = await cjkFile.readAsBytes();
          for (final family in [
            'PingFang SC',
            'packages/shadcn_ui/PingFang SC',
          ]) {
            final loader = FontLoader(family)
              ..addFont(Future.value(ByteData.sublistView(bytes)));
            await loader.load();
          }
        }
      });
      debugPrint('TMDB live: fonts ready; rendering screenshots');
      final warmContext = GlobalKey();
      await tester.pumpWidget(OpenPlayXApp(home: SizedBox(key: warmContext)));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await for (final file in Directory('${root.path}/artwork').list()) {
          if (file is! File || file.path.endsWith('.tmp')) continue;
          await precacheImage(
            ResizeImage(FileImage(file), width: 600),
            warmContext.currentContext!,
            onError: (error, stack) =>
                throw StateError('Downloaded artwork could not be decoded'),
          );
        }
      });
      await tester.pumpAndSettle();
      debugPrint('TMDB live: artwork decoded into UI image cache');

      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      Future<void> capture(
        String name,
        GlobalKey boundary, {
        int minimumImages = 1,
      }) async {
        for (var i = 0; i < 30; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pumpAndSettle();
          if (find.byType(Image).evaluate().length >= minimumImages) break;
        }
        expect(
          find.byType(Image).evaluate().length,
          greaterThanOrEqualTo(minimumImages),
        );
        final images = tester.widgetList<Image>(find.byType(Image)).toList();
        debugPrint(
          'TMDB live: capturing $name with ${images.length} image widgets',
        );
        expect(
          find
              .byType(RawImage)
              .evaluate()
              .where((e) => (e.widget as RawImage).image != null)
              .length,
          greaterThanOrEqualTo(minimumImages),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await File('${root.path}/$name.png')
              .writeAsBytes(data!.buffer.asUint8List());
        });
      }

      for (final width in [1200.0, 390.0]) {
        tester.view.physicalSize = Size(width, 900);
        var boundary = GlobalKey();
        var appearance = AppThemeController(initialLanguage: 'zh-Hans');
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: OpenPlayXApp(
              appearance: appearance,
              home: LibraryPage(sources: sources, service: library),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture(
          'library-${width.toInt()}',
          boundary,
          minimumImages: width > 1000 ? 6 : 2,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        appearance.dispose();
        boundary = GlobalKey();
        appearance = AppThemeController(initialLanguage: 'zh-Hans');
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: OpenPlayXApp(
              appearance: appearance,
              home: MetadataPage(
                library: library,
                sources: sources,
                media: firstMedia,
                service: service,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture('detail-${width.toInt()}', boundary, minimumImages: 2);
        await tester.ensureVisible(find.text('选择海报'));
        await tester.pumpAndSettle();
        await capture('artwork-${width.toInt()}', boundary, minimumImages: 12);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        appearance.dispose();
      }
    },
    skip: output.isEmpty,
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
