import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/core/plugins/metadata_capability.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/metadata/metadata_queue.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/services/artwork/artwork_service.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx/services/metadata/media_name_parser.dart';
import 'package:openplayx/services/metadata/metadata_background.dart';
import 'package:openplayx/services/metadata/metadata_queue_runner.dart';
import 'package:openplayx/services/metadata/metadata_runtime.dart';
import 'package:openplayx/services/metadata/metadata_service.dart';

import 'metadata_page_test.dart' show OfflineSources;
import 'metadata_test.dart' show FixtureSources;

class TestMetadataProvider implements Plugin, MetadataCapability {
  int calls = 0;
  bool remake = false;
  PluginException? failure;
  Completer<MetadataResult>? pending;
  @override
  PluginManifest get manifest =>
      const PluginManifest('metadata.test', 'Test', browseExperience: 'none');
  @override
  Set<MetadataAction> get actions => MetadataAction.values.toSet();
  MetadataRecord movie(String id, {bool details = false}) => MetadataRecord(
    ref: MetadataRef('tmdb', MediaKind.movie, id),
    fields: {
      'title': details ? '已识别影片' : 'Film',
      'originalTitle': 'Film',
      'year': 2014,
      if (details) 'overview': 'Provider synopsis',
    },
    artwork: details
        ? const [ArtworkDescriptor(id: 'poster', type: 'poster', remote: null)]
        : [],
  );
  @override
  Future<MetadataResult> lookup(
    MetadataRequest request,
    CallContext context,
  ) async {
    calls++;
    if (failure != null) throw failure!;
    if (request.action == MetadataAction.search) {
      if (pending != null) return pending!.future;
      return MetadataResult([movie('1'), if (remake) movie('2')]);
    }
    return MetadataResult([movie(request.ref!.id, details: true)]);
  }

  @override
  Future<void> dispose() async {}
}

class TestArtwork extends ArtworkService {
  TestArtwork(super.sources);
  final fetched = <String>[];
  @override
  Future<File> load(ArtworkDescriptor artwork) async {
    fetched.add(artwork.id);
    return File('/test-artwork');
  }
}

class TestScheduler implements MetadataScheduler {
  TestScheduler(this.native);
  @override
  final bool native;
  int starts = 0, schedules = 0;
  @override
  Future<void> initialize() async {
    starts++;
  }

  @override
  Future<void> schedule({bool collect = true, bool online = true}) async {
    schedules++;
  }
}

class RemoteSources extends OfflineSources {
  int reads = 0;
  @override
  List<SourceConfig> get configs => const [
    SourceConfig(
      id: 'nas',
      kind: SourceKind.smb,
      name: 'NAS',
      address: 'smb://host/share',
    ),
  ];
  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) async {
    reads++;
    return const BrowseResult([]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LibraryService library;
  late OfflineSources sources;
  late String media;
  late TestMetadataProvider provider;
  late TestArtwork artwork;
  MetadataQueueRunner runner() => MetadataQueueRunner(
    library,
    sources,
    registry: MetadataRegistry()..register('tmdb', provider),
    artwork: artwork,
  );
  setUp(() {
    library = LibraryService(
      sqlite3.openInMemory(),
      watchExternalChanges: false,
    );
    sources = OfflineSources();
    provider = TestMetadataProvider();
    artwork = TestArtwork(sources);
    media = library.register(
      const SourceEntry(
        ResourceRef('@local', '/Film.2014.mkv'),
        'Film.2014.mkv',
        isFolder: false,
      ),
    );
  });
  tearDown(() => library.close());
  test(
    'SMB sidecars wait for a network worker and are still inspected there',
    () async {
      final remote = RemoteSources();
      final item = library.register(
        const SourceEntry(
          ResourceRef('nas', '/share/Film.2014.mkv'),
          'Film.2014.mkv',
          isFolder: false,
        ),
      );
      library.addManual(item);
      final worker = MetadataQueueRunner(
        library,
        remote,
        registry: MetadataRegistry()..register('tmdb', provider),
        artwork: artwork,
      );
      try {
        await worker.reconcile();
        await worker.runBatch(allowOnline: false);
        expect(remote.reads, 0);
        expect(worker.queue.item(item)!['phase'], 2);
        await worker.runBatch();
        expect(remote.reads, 1);
        expect(worker.queue.item(item)!['state'], 'completed');
        expect(library.metadata.fields(item)['title'], '已识别影片');
      } finally {
        await worker.dispose();
      }
    },
  );

  test('direct open never enqueues; every library membership persists pending work', () {
    final queue = MetadataQueue(library.db);
    expect(queue.item(media), isNull);
    library.addManual(media);
    expect(queue.item(media)!['state'], 'queued');
    library.addManual(media);
    expect(library.db.select('SELECT * FROM metadata_queue'), hasLength(1));
  });
  test('unique exact match automatically updates title, association and image cache', () async {
    library.addManual(media);
    final worker = runner();
    try {
      await worker.reconcile();
      await worker.runBatch();
      expect(worker.queue.item(media)!['state'], 'completed');
      expect(library.query().single['title'], '已识别影片');
      expect(library.metadata.association(media)!.id, '1');
      expect(library.metadata.confirmed(media), isFalse);
      expect(library.metadata.selectedArtwork(media)!.id, 'poster');
      expect(artwork.fetched, ['poster']);
      final before = provider.calls;
      await worker.reconcile();
      await worker.runBatch();
      expect(provider.calls, before);
    } finally {
      await worker.dispose();
    }
  });
  test('multiple exact candidates await selection instead of adopting the first result', () async {
    provider.remake = true;
    library.addManual(media);
    final worker = runner();
    try {
      await worker.reconcile();
      await worker.runBatch();
      expect(worker.queue.item(media)!['state'], 'awaitingSelection');
      expect(library.metadata.association(media), isNull);
      expect(library.metadata.latestJob(media)!['stage'], 'awaitingSelection');
      expect(artwork.fetched, isEmpty);
    } finally {
      await worker.dispose();
    }
  });
  test('manual confirmation clears a waiting badge and completes the selected artwork', () async {
    provider.remake = true;
    library.addManual(media);
    final worker = runner();
    final manual = MetadataService(
      library,
      sources,
      registry: MetadataRegistry()..register('tmdb', provider),
    );
    try {
      await worker.reconcile();
      await worker.runBatch();
      expect(worker.queue.item(media)!['state'], 'awaitingSelection');
      final job = worker.queue.item(media)!['job_id'] as String;
      await manual.confirm(job, provider.movie('2').ref);
      await worker.reconcile();
      await worker.runBatch();
      expect(worker.queue.item(media)!['state'], 'completed');
      expect(library.metadata.association(media)!.id, '2');
      expect(library.metadata.confirmed(media), isTrue);
      expect(artwork.fetched, ['poster']);
    } finally {
      await manual.dispose();
      await worker.dispose();
    }
  });
  test(
    'system stop releases work and prevents a late response from applying',
    () async {
      provider.pending = Completer<MetadataResult>();
      library.addManual(media);
      final worker = runner();
      try {
        await worker.reconcile();
        final task = worker.runBatch();
        await Future<void>.delayed(Duration.zero);
        worker.stop();
        provider.pending!.complete(MetadataResult([provider.movie('1')]));
        await task;
        expect(library.metadata.association(media), isNull);
        expect(worker.queue.item(media)!['state'], 'queued');
        expect(worker.queue.item(media)!['lease_owner'], isNull);
      } finally {
        await worker.dispose();
      }
    },
  );
  test('match policy requires exact title, consistent year and a complete result page', () {
    final evidence = const MediaNameParser().parse('Film.2014.mkv');
    expect(
      MetadataQueueRunner.uniqueMatch(evidence, [provider.movie('1')])!.ref.id,
      '1',
    );
    expect(
      MetadataQueueRunner.uniqueMatch(evidence, [
        provider.movie('1'),
      ], completePage: false),
      isNull,
    );
    expect(
      MetadataQueueRunner.uniqueMatch(evidence, [
        MetadataRecord(
          ref: const MetadataRef('tmdb', MediaKind.movie, '2'),
          fields: const {'title': 'Film', 'year': 1984},
        ),
      ]),
      isNull,
    );
    expect(
      MetadataQueueRunner.uniqueMatch(evidence, [
        MetadataRecord(
          ref: const MetadataRef('tmdb', MediaKind.movie, '3'),
          fields: const {'title': 'Film sequel', 'year': 2014},
        ),
      ]),
      isNull,
    );
  });
  test('no configured provider waits for configuration without retrying authentication forever', () async {
    library.addManual(media);
    final worker = MetadataQueueRunner(
      library,
      sources,
      credentials: () async => null,
      artwork: artwork,
    );
    try {
      await worker.reconcile();
      await worker.runBatch();
      expect(worker.queue.item(media)!['state'], 'waitingConfiguration');
      expect(worker.queue.pending(), isFalse);
      expect(library.resources(media), hasLength(1));
    } finally {
      await worker.dispose();
    }
    library.metadata.setSetting('tmdbRevision', 'new-test-configuration');
    final configured = runner();
    try {
      await configured.reconcile();
      await configured.runBatch();
      expect(configured.queue.item(media)!['state'], 'completed');
    } finally {
      await configured.dispose();
    }
  });
  test('transient failures back off and stop after a bounded number of item attempts', () async {
    provider.failure = const PluginException(
      'networkUnavailable',
      'offline',
      retryable: true,
    );
    library.addManual(media);
    final worker = runner();
    try {
      await worker.reconcile();
      for (var index = 0; index < 5; index++) {
        library.db.execute('UPDATE metadata_queue SET next_at=0');
        await worker.runBatch();
      }
      expect(worker.queue.item(media)!['state'], 'failed');
      expect(worker.queue.item(media)!['attempts'], 5);
      expect(provider.calls, 5);
      expect(worker.queue.pending(), isFalse);
    } finally {
      await worker.dispose();
    }
  });
  test(
    'user editing while search runs invalidates the background result',
    () async {
      provider.pending = Completer<MetadataResult>();
      library.addManual(media);
      final worker = runner();
      try {
        await worker.reconcile();
        final task = worker.runBatch();
        await Future<void>.delayed(Duration.zero);
        library.rename(media, 'User title');
        provider.pending!.complete(MetadataResult([provider.movie('1')]));
        await task;
        expect(library.metadata.fields(media)['title'], 'User title');
        expect(library.metadata.association(media), isNull);
        expect(worker.queue.item(media)!['state'], 'queued');
      } finally {
        await worker.dispose();
      }
    },
  );
  test('removing media during a query prevents the result from being applied or retried', () async {
    provider.pending = Completer<MetadataResult>();
    library.addManual(media);
    final worker = runner();
    try {
      await worker.reconcile();
      final task = worker.runBatch();
      await Future<void>.delayed(Duration.zero);
      library.hide(media);
      provider.pending!.complete(MetadataResult([provider.movie('1')]));
      await task;
      expect(library.metadata.association(media), isNull);
      expect(worker.queue.item(media)!['state'], 'cancelled');
    } finally {
      await worker.dispose();
    }
  });
  test(
    'local-only batch imports NFO offline and never reads online credentials',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'openplayx-background-local-',
      );
      final file = await File('${root.path}/Film.mkv').writeAsString('fixture');
      await File('${root.path}/Film.nfo').writeAsString(
        '<movie><title>Offline NFO title</title><plot>Local synopsis</plot></movie>',
      );
      final local = FixtureSources(root);
      final item = library.register(
        SourceEntry(
          ResourceRef('files', file.path),
          'Film.mkv',
          isFolder: false,
        ),
      );
      library.addManual(item);
      var credentialReads = 0;
      final worker = MetadataQueueRunner(
        library,
        local,
        credentials: () async {
          credentialReads++;
          return null;
        },
        artwork: TestArtwork(local),
      );
      try {
        await worker.reconcile();
        await worker.runBatch(allowOnline: false);
        expect(library.metadata.fields(item)['title'], 'Offline NFO title');
        expect(worker.queue.item(item)!['state'], 'completed');
        expect(credentialReads, 0);
        expect(worker.queue.item(media), isNull);
      } finally {
        await worker.dispose();
        await root.delete(recursive: true);
      }
    },
  );
  test('native runtime schedules persistent workers without depending on a library page', () async {
    library.addManual(media);
    final scheduler = TestScheduler(true);
    final runtime = MetadataRuntime(
      library,
      sources,
      scheduler: scheduler,
      runnerFactory: runner,
    );
    try {
      await runtime.start();
      expect(scheduler.starts, 1);
      expect(scheduler.schedules, 1);
      expect(provider.calls, 0);
      expect(MetadataQueue(library.db).item(media)!['state'], 'queued');
    } finally {
      await runtime.dispose();
    }
  });
  test('foreground host uses the same automatic pipeline when native scheduling is unavailable', () async {
    library.addManual(media);
    final runtime = MetadataRuntime(
      library,
      sources,
      scheduler: TestScheduler(false),
      runnerFactory: runner,
    );
    try {
      await runtime.start();
      await Future<void>.delayed(Duration.zero);
      expect(library.metadata.fields(media)['title'], '已识别影片');
    } finally {
      await runtime.dispose();
    }
  });
}
