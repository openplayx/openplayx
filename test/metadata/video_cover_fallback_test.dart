import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/core/capabilities/metadata_capability.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/metadata/metadata_queue_runner.dart';

import 'metadata_background_test.dart' show TestArtwork, TestMetadataProvider;
import 'metadata_page_test.dart' show OfflineSources;
import '../support/library_test_helpers.dart';

class EmptyCatalog extends TestMetadataProvider {
  int? nextPage;
  @override
  Future<MetadataResult> lookup(
    MetadataRequest request,
    CallContext context,
  ) async {
    if (failure != null) throw failure!;
    return MetadataResult([], nextPage: nextPage);
  }
}

class CoverArtwork extends TestArtwork {
  CoverArtwork(super.sources);
  bool fail = false;
  void Function()? onLoad;
  @override
  Future<File> load(ArtworkDescriptor artwork) async {
    fetched.add(artwork.id);
    onLoad?.call();
    if (fail) throw StateError('unreadable video');
    return File('/test-cover');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LibraryService library;
  late EmptyCatalog catalog;
  late CoverArtwork artwork;
  late MetadataQueueRunner worker;
  late String media;

  setUp(() {
    library = LibraryService(
      sqlite3.openInMemory(),
      watchExternalChanges: false,
    );
    final sources = OfflineSources();
    catalog = EmptyCatalog();
    artwork = CoverArtwork(sources);
    worker = MetadataQueueRunner(
      library,
      sources,
      registry: MetadataRegistry()..register('tmdb', catalog),
      artwork: artwork,
    );
    media = library.register(
      const SourceEntry(
        ResourceRef('@local', '/Film.2014.mkv'),
        'Film.2014.mkv',
        isFolder: false,
      ),
    );
    addToLibrary(library, media);
  });
  tearDown(() async {
    await worker.dispose();
    library.close();
  });

  Future<void> run() async {
    await worker.reconcile();
    await worker.runBatch();
  }

  test(
    'a complete catalog miss publishes a regenerable cover without a match',
    () async {
      await run();
      final cover = library.metadata.selectedArtwork(media)!;
      expect(cover.id, startsWith('video-cover-one-fifth:'));
      expect(cover.source!.instanceId, '@local');
      expect(cover.source!.id, '/Film.2014.mkv');
      expect(cover.type, 'poster');
      expect(library.metadata.association(media), isNull);
      expect(worker.queue.item(media)!['state'], 'unmatched');
      await run();
      expect(artwork.fetched, hasLength(1));
    },
  );

  test(
    'an incomplete empty page awaits selection without extracting a cover',
    () async {
      catalog.nextPage = 2;
      await run();
      expect(artwork.fetched, isEmpty);
      expect(worker.queue.item(media)!['state'], 'awaitingSelection');
    },
  );

  test('network failure never triggers a fallback', () async {
    catalog.failure = PluginException(
      'networkUnavailable',
      'offline',
      retryable: true,
    );
    await run();
    expect(artwork.fetched, isEmpty);
    expect(library.metadata.selectedArtwork(media), isNull);
    expect(worker.queue.item(media)!['state'], 'queued');
  });

  test(
    'extraction failure leaves the catalog miss without a broken selection',
    () async {
      artwork.fail = true;
      await run();
      expect(library.metadata.selectedArtwork(media), isNull);
      expect(worker.queue.item(media)!['state'], 'unmatched');
    },
  );

  test('stopping while extracting cannot publish the cover', () async {
    artwork.onLoad = worker.stop;
    await run();
    expect(library.metadata.selectedArtwork(media), isNull);
  });

  test('an edit during extraction prevents publishing a stale cover', () async {
    artwork.onLoad = () => library.metadata.overrideField(
      media,
      'title',
      'My title',
      expectedRevision: library.metadata.revision(media),
    );
    await run();
    expect(library.metadata.selectedArtwork(media), isNull);
    expect(library.metadata.fields(media)['title'], 'My title');
  });

  test('an existing manual title survives fallback publication', () async {
    library.metadata.overrideField(
      media,
      'title',
      'My title',
      expectedRevision: library.metadata.revision(media),
    );
    await run();
    expect(library.metadata.selectedArtwork(media), isNotNull);
    expect(library.metadata.fields(media)['title'], 'My title');
  });

  test('existing artwork is preserved without extraction', () async {
    final metadata = library.metadata;
    library.transaction(
      () => metadata.apply(
        media,
        MetadataRecord(
          ref: MetadataRef('nfo:fixture', MediaKind.movie, media),
          fields: const {},
          artwork: const [ArtworkDescriptor(id: 'existing', type: 'poster')],
        ),
        sourceKey: 'fixture',
        authority: 10,
        expectedRevision: metadata.revision(media),
        operationId: 'existing',
      ),
    );
    metadata.selectArtwork(
      media,
      metadata.selectedArtwork(media)!,
      expectedRevision: metadata.revision(media),
    );
    await run();
    expect(artwork.fetched, isEmpty);
    expect(metadata.selectedArtwork(media)!.id, 'existing');
    expect(metadata.artworkLocked(media), isTrue);
  });
}
