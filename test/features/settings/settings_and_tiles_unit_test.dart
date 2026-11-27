import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/assistant/plugins/external/external_service_registry.dart';
import 'package:openplayx/assistant/plugins/external/external_service_setup.dart';
import 'package:openplayx/capabilities/artwork/artwork_service.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/metadata/metadata_service.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/core/capabilities/metadata_capability.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/features/assistant/view/plugins/external_service_config_page.dart';
import 'package:openplayx/features/library/view/media_tiles.dart';
import 'package:openplayx/features/library/view/metadata_page.dart';
import 'package:openplayx/features/settings/settings_page.dart';
import 'package:openplayx/features/sources/view/hidden_connector_sources.dart';
import 'package:openplayx/ui/components/states/content_state.dart';
import 'package:sqlite3/sqlite3.dart' hide Row;

import '../../app_test_host.dart';
import '../../support/fake_sources.dart';
import '../../support/library_test_helpers.dart';

final _png = Uint8List.fromList(const [
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

class _FakeExternalSetup extends ExternalServiceSetup {
  _FakeExternalSetup(Database db)
    : super(registry: ExternalServiceRegistry(db: db));

  Object? probeError;

  @override
  Future<ExternalServiceProbe> probe(String address, String token) async {
    if (probeError != null) throw probeError!;
    return const ExternalServiceProbe(
      baseUrl: 'https://mcp.example',
      endpoint: 'https://mcp.example/mcp',
      serverName: 'demo-mcp',
      title: 'Demo MCP',
      version: '1.0.0',
      tools: ['search_web', 'fetch_doc'],
    );
  }

  @override
  Future<ExternalService> save(
    ExternalServiceProbe probe,
    String token, {
    String? name,
  }) async => ExternalService(
    id: 'ext-1',
    name: name?.trim().isNotEmpty == true ? name!.trim() : probe.title,
    baseUrl: probe.baseUrl,
    endpoint: probe.endpoint,
    serverName: probe.serverName,
    serverTitle: probe.title,
    version: probe.version,
    tools: probe.tools,
    available: true,
    checkedAt: DateTime.now(),
  );
}

void main() {
  testWidgets('SettingsPage renders desktop & compact views and opens subpages', (
    tester,
  ) async {
    final library = LibraryService(sqlite3.openInMemory());
    final sources = SourceManager();
    addTearDown(library.close);

    for (final size in const [Size(1280, 900), Size(420, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        TestApp(home: SettingsPage(library: library, sources: sources)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
    }

    final playerRow = find.byKey(const ValueKey('settings-player'));
    if (playerRow.evaluate().isNotEmpty) {
      await tester.tap(playerRow);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(Navigator).last)).maybePop();
      await tester.pumpAndSettle();
    }
    final subsRow = find.byKey(const ValueKey('settings-subtitles'));
    if (subsRow.evaluate().isNotEmpty) {
      await tester.tap(subsRow);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(Navigator).last)).maybePop();
      await tester.pumpAndSettle();
    }
    tester.view.reset();
  });

  testWidgets('MediaTileInfo, LibraryPosterTile and LibraryResumeTile render', (
    tester,
  ) async {
    final tmp = Directory.systemTemp.createTempSync('opx_tiles_');
    final img = File('${tmp.path}/p.png')..writeAsBytesSync(_png);
    final library = LibraryService(sqlite3.openInMemory());
    final sources = Sources();
    final artwork = _FakeArtwork(sources, img);
    addTearDown(() {
      library.close();
      tmp.deleteSync(recursive: true);
    });

    final movieId = library.register(
      const SourceEntry(ResourceRef('s', '/m.mkv'), 'm.mkv', isFolder: false),
    );
    addToLibrary(library, movieId);
    library.transaction(
      () => library.metadata.apply(
        movieId,
        const MetadataRecord(
          ref: MetadataRef('tmdb', MediaKind.movie, '1'),
          fields: {
            'title': 'Sample Movie',
            'year': 2024,
            'airDate': '2024-05-01',
            'ratings': {
              'tmdb': {'value': 8.4, 'max': 10},
            },
          },
          artwork: [
            ArtworkDescriptor(id: 'p1', type: 'poster'),
            ArtworkDescriptor(id: 'b1', type: 'backdrop'),
          ],
        ),
        sourceKey: 'tmdb',
        authority: 100,
        expectedRevision: 0,
        operationId: 'tile-1',
        select: true,
      ),
    );

    final row = library.query().first;
    late BuildContext ctx;
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return Row(
                children: [
                  SizedBox(
                    width: 160,
                    height: 320,
                    child: LibraryPosterTile(
                      service: library,
                      artwork: artwork,
                      media: row,
                      fullDate: true,
                      onTap: () {},
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    height: 240,
                    child: LibraryResumeTile(
                      service: library,
                      artwork: artwork,
                      row: {...row, 'position': 45000, 'duration': 120000},
                      onTap: () {},
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();

    expect(MediaTileInfo.clock(65000), '01:05');
    expect(MediaTileInfo.clock(3665000), '1:01:05');
    expect(
      MediaTileInfo.subtitle(ctx, library, movieId, {
        'kind': 'episode',
        'season': 2,
        'episode': 5,
      }),
      isNotEmpty,
    );
    expect(
      MediaTileInfo.subtitle(ctx, library, movieId, {'airDate': '2020-01-02'}),
      '2020',
    );
    expect(
      MediaTileInfo.artwork(library, artwork, movieId, landscape: true),
      isNotNull,
    );
  });

  testWidgets('ExternalServiceConfigPage handles connect, error and save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = sqlite3.openInMemory();
    final setup = _FakeExternalSetup(db);
    addTearDown(db.close);

    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (c) => ElevatedButton(
            onPressed: () => Navigator.of(c).push(
              MaterialPageRoute<bool>(
                builder: (_) => ExternalServiceConfigPage(setup: setup),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    setup.probeError = const ExternalServiceException('unreachable');
    final connectBtn = find.byKey(const ValueKey('external-connect'));
    await tester.tap(connectBtn);
    await tester.pumpAndSettle();
    expect(find.textContaining('unreachable'), findsWidgets);

    setup.probeError = const FormatException('bad url');
    await tester.tap(connectBtn);
    await tester.pumpAndSettle();
    expect(find.textContaining('bad url'), findsWidgets);

    setup.probeError = null;
    await tester.tap(connectBtn);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('external-detected')), findsOneWidget);
    expect(find.textContaining('Demo MCP'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('external-save')));
    await tester.pumpAndSettle();
  });

  testWidgets('ContentState and showHiddenConnectorSources render all states', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: ContentState(
                  message: 'Empty',
                  onRetry: () => retried++,
                  retryLabel: 'Retry',
                ),
              ),
              const Expanded(
                child: ContentState(message: 'Loading', loading: true),
              ),
              const Expanded(
                child: ContentState(message: 'Failed', error: true),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Retry'));
    expect(retried, 1);

    final manager = SourceManager();
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (c) => ElevatedButton(
            onPressed: () => showHiddenConnectorSources(c, manager),
            child: const Text('Hidden'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hidden'));
    await tester.pumpAndSettle();
  });

  testWidgets('MetadataPage renders matched record, artwork and locks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
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
    library.transaction(
      () => library.metadata.apply(
        movieId,
        const MetadataRecord(
          ref: MetadataRef('tmdb', MediaKind.movie, '503919'),
          fields: {
            'title': 'The Lighthouse',
            'year': 2019,
            'overview': 'Two lighthouse keepers.',
          },
          artwork: [
            ArtworkDescriptor(id: 'p1', type: 'poster'),
            ArtworkDescriptor(id: 'b1', type: 'backdrop'),
          ],
        ),
        sourceKey: 'tmdb',
        authority: 100,
        expectedRevision: 0,
        operationId: 'meta-1',
        select: true,
      ),
    );

    final metaService = MetadataService(library, sources);
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
    expect(find.byType(MetadataPage), findsOneWidget);
    expect(find.textContaining('The Lighthouse'), findsWidgets);
  });
}
