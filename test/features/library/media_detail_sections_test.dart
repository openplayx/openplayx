import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/artwork/artwork_service.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/core/capabilities/metadata_capability.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/features/library/view/media_detail_page.dart';
import 'package:openplayx/features/library/view/title_logo.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:openplayx/ui/components/media/playback_progress.dart';
import 'package:openplayx/ui/theme/app_theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../support/fake_sources.dart';
import '../../support/library_test_helpers.dart';

// 1x1 transparent PNG
final _pngBytes = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FakeArtwork extends ArtworkService {
  _FakeArtwork(super.sources, this.file);
  final File file;
  @override
  Future<File> load(ArtworkDescriptor artwork) async => file;
}

class _SeriesSources extends Sources {
  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) async {
    if (request.node == null) {
      return const BrowseResult([
        SourceEntry(
          ResourceRef('s', 'show'),
          'Show',
          isFolder: true,
          media: SourceMediaInfo(id: 'show', title: 'Show', kind: 'series'),
        ),
      ]);
    }
    if (request.node!.id == 'show') {
      return const BrowseResult([
        SourceEntry(
          ResourceRef('s', 's1'),
          'Season 1',
          isFolder: true,
          media: SourceMediaInfo(
            id: 's1',
            title: 'Season 1',
            kind: 'season',
            parentId: 'show',
            season: 1,
          ),
        ),
      ]);
    }
    return const BrowseResult([
      SourceEntry(
        ResourceRef('s', 'e1.mkv'),
        'e1.mkv',
        isFolder: false,
        media: SourceMediaInfo(
          id: 'e1',
          title: 'Pilot',
          kind: 'episode',
          parentId: 's1',
          season: 1,
          episode: 1,
        ),
      ),
      SourceEntry(
        ResourceRef('s', 'e2.mkv'),
        'e2.mkv',
        isFolder: false,
        media: SourceMediaInfo(
          id: 'e2',
          title: 'Second',
          kind: 'episode',
          parentId: 's1',
          season: 1,
          episode: 2,
        ),
      ),
    ]);
  }
}

Widget _host(Widget child) => ShadApp.custom(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: ThemeMode.light,
  appBuilder: (context) => MaterialApp(
    theme: Theme.of(context),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      GlobalShadLocalizations.delegate,
      ...AppLocalizations.localizationsDelegates,
    ],
    builder: (context, child) => ShadAppBuilder(child: child!),
    home: child,
  ),
);

void main() {
  testWidgets('MediaDetailPage renders rich movie in wide and narrow layouts', (
    tester,
  ) async {
    final tmp = Directory.systemTemp.createTempSync('opx_detail_ui_');
    final img = File('${tmp.path}/art.png')..writeAsBytesSync(_pngBytes);
    final db = sqlite3.openInMemory();
    final sources = Sources();
    final library = LibraryService(db);
    final artwork = _FakeArtwork(sources, img);
    addTearDown(() {
      library.close();
      tmp.deleteSync(recursive: true);
    });

    final movieId = library.register(
      const SourceEntry(
        ResourceRef('s', '/lighthouse.mkv'),
        'lighthouse.mkv',
        isFolder: false,
      ),
    );
    addToLibrary(library, movieId);
    final sequelId = library.register(
      const SourceEntry(
        ResourceRef('s', '/lighthouse2.mkv'),
        'lighthouse2.mkv',
        isFolder: false,
      ),
    );
    addToLibrary(library, sequelId);

    void apply(String id, Map<String, dynamic> fields, String extId) {
      library.transaction(
        () => library.metadata.apply(
          id,
          MetadataRecord(
            ref: MetadataRef('tmdb', MediaKind.movie, extId),
            fields: fields,
            artwork: const [
              ArtworkDescriptor(id: 'poster', type: 'poster'),
              ArtworkDescriptor(id: 'backdrop', type: 'backdrop'),
            ],
          ),
          sourceKey: 'tmdb',
          authority: 100,
          expectedRevision: 0,
          operationId: 'op-$extId',
          select: true,
        ),
      );
    }

    apply(movieId, {
      'title': 'The Lighthouse',
      'originalTitle': 'The Lighthouse',
      'year': 2019,
      'airDate': '2019-10-18',
      'runtime': 109,
      'certification': 'R',
      'countries': ['US', 'CA'],
      'genres': ['Drama', 'Mystery'],
      'ratings': {
        'tmdb': {'value': 7.5, 'max': 10},
        'imdb': {'value': 7.4, 'max': 10},
        'rottentomatoes': {'value': 90, 'max': 100},
      },
      'overview': 'Two lighthouse keepers try to maintain their sanity.',
      'cast': [
        {'name': 'Willem Dafoe', 'role': 'Thomas Wake'},
        {'name': 'Robert Pattinson', 'role': 'Ephraim Winslow'},
      ],
      'directors': ['Robert Eggers'],
      'collection': {'id': '9', 'name': 'Lighthouse Collection'},
    }, '503919');
    apply(sequelId, {
      'title': 'The Lighthouse 2',
      'year': 2022,
      'collection': {'id': '9', 'name': 'Lighthouse Collection'},
    }, '503920');

    final movie = library.query().firstWhere((m) => m['id'] == movieId);
    var played = 0;
    for (final size in const [Size(1280, 1200), Size(420, 1200)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _host(
          MediaDetailPage(
            service: library,
            sources: sources,
            artwork: artwork,
            media: movie,
            play: (_, _) async => played++,
            resourceLabel: (v) => v.name,
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
      expect(find.textContaining('The Lighthouse'), findsWidgets);
      expect(find.text('Play'), findsWidgets);
    }
    tester.view.reset();

    await tester.tap(find.text('Play').first);
    await tester.pump();
    expect(played, 1);
  });

  testWidgets('MediaDetailPage renders series with seasons and episodes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final tmp = Directory.systemTemp.createTempSync('opx_series_ui_');
    final img = File('${tmp.path}/art.png')..writeAsBytesSync(_pngBytes);
    final db = sqlite3.openInMemory();
    final sources = _SeriesSources();
    final library = LibraryService(db);
    final artwork = _FakeArtwork(sources, img);
    addTearDown(() {
      library.close();
      tmp.deleteSync(recursive: true);
    });

    final fs = library.addFileSource('s', name: 'NAS');
    await tester.runAsync(() => library.scan(fs, sources));
    final show = library.query(search: 'Show').first;

    await tester.pumpWidget(
      _host(
        MediaDetailPage(
          service: library,
          sources: sources,
          artwork: artwork,
          media: show,
          play: (_, _) async {},
          resourceLabel: (v) => v.name,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    expect(find.textContaining('Show'), findsWidgets);
    expect(find.textContaining('Pilot'), findsWidgets);
  });

  testWidgets('TitleLogo shows fallback when empty or after patience timeout', (
    tester,
  ) async {
    final tmp = Directory.systemTemp.createTempSync('opx_logo_ui_');
    final img = File('${tmp.path}/logo.png')..writeAsBytesSync(_pngBytes);
    final artwork = _FakeArtwork(SourceManager(), img);
    addTearDown(() => tmp.deleteSync(recursive: true));

    await tester.pumpWidget(
      _host(
        TitleLogo(
          service: artwork,
          logos: const [],
          fallback: const Text('Fallback Title'),
        ),
      ),
    );
    expect(find.text('Fallback Title'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        TitleLogo(
          service: artwork,
          logos: [
            ArtworkDescriptor(
              id: 'logo-1',
              type: 'logo',
              remote: Uri.parse('https://example.invalid/logo.png'),
              language: 'en',
            ),
          ],
          patience: const Duration(milliseconds: 20),
          fallback: const Text('Fallback Title 2'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  });

  testWidgets('PlaybackProgress handles keyboard stepping and disabled state', (
    tester,
  ) async {
    final previews = <double>[];
    final commits = <double>[];
    await tester.pumpWidget(
      _host(
        Scaffold(
          body: Center(
            child: PlaybackProgress(
              value: 30000,
              max: 100000,
              enabled: true,
              label: 'Seek',
              onPreview: previews.add,
              onCommit: commits.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Request focus on the Focus widget inside PlaybackProgress
    final sliderEl = tester.element(find.byType(ShadSlider));
    Focus.of(sliderEl).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(commits, isNotEmpty);

    await tester.pumpWidget(
      _host(
        Scaffold(
          body: Center(
            child: PlaybackProgress(
              value: 0,
              max: 0,
              enabled: false,
              label: 'Seek',
              onPreview: (_) {},
              onCommit: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  });
}
