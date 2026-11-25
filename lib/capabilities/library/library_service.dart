import 'dart:async';

import '../../data/analytics/analytics_service.dart';

import 'dart:io';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../../core/capabilities/source_capability.dart';
import '../../core/capabilities/metadata_capability.dart';
import '../../data/configuration/configuration_database.dart';
import '../../data/metadata/metadata_repository.dart';
import '../../data/library/library_database.dart';
import '../../data/library/scan_status.dart';
import '../../data/library/library_repository.dart';
import '../sources/source_manager.dart';
import 'file_source.dart';
import 'media_models.dart';
import '../../data/sources/source_config.dart';
import '../../l10n/l10n.dart';

/// Library business operations: identity, membership, source traversal and playback.
/// [LibraryRepository] owns SQL and metadata storage; [LibraryDatabase] owns
/// opening, schema migration and recovery. Media identity survives removal.
class LibraryService {
  /// [db] is the library database (data the App produces); [configuration]
  /// is `configuration.sqlite3` (what the user configured), in memory when
  /// omitted. The service owns and closes both.
  LibraryService(
    Database db, {
    Database? configuration,
    bool recoverInterrupted = true,
    bool watchExternalChanges = false,
  }) {
    repository = LibraryRepository(
      db,
      configuration: configuration,
      recoverInterrupted: recoverInterrupted,
      onChanged: notifyChanged,
    );
    _dataVersion = repository.dataVersion;
    if (watchExternalChanges) {
      _externalWatch = Timer.periodic(
        const Duration(seconds: 2),
        (_) => checkExternalChanges(),
      );
    }
  }
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  Timer? _externalWatch;
  final _followed = <SourceManager, StreamSubscription<SourceChange>>{};

  /// Keeps the library consistent with [sources]: a removed connection takes
  /// its file sources and what only they brought in along; a connection
  /// switched on or off shows or hides its media.
  void followSources(SourceManager sources) {
    repository.connectionVisible = sources.sourceVisibleToAccount;
    _followed[sources] ??= sources.changes.listen((change) {
      if (_closeRequested) return;
      switch (change) {
        case SourceRemoved(:final id):
          removeFileSourcesOf(id);
        case SourceDirectoryChanged():
        case SourceEnabledChanged():
          notifyChanged();
      }
    });
  }

  int _dataVersion = 0;
  bool _inTransaction = false;
  bool _databaseClosed = false;
  void notifyChanged() {
    if (_closeRequested || _changes.isClosed) return;
    if (_inTransaction) return;
    // Leading + trailing throttle while background metadata work runs; it emits several
    // changes per item and every listener rebuilds with synchronous queries.
    if (_notifyTimer != null) {
      _notifyPending = true;
      return;
    }
    _changes.add(null);
    if (_running.isEmpty) return;
    _notifyTimer = Timer(const Duration(milliseconds: 300), () {
      _notifyTimer = null;
      if (_notifyPending) {
        _notifyPending = false;
        notifyChanged();
      }
    });
  }

  Timer? _notifyTimer;

  /// Metadata scraping progress (done/total) for the library page header.
  ({int done, int total}) metadataProgress() => repository.metadataProgress();

  /// Scraping progress of the media found by one file source.
  ({int done, int total}) metadataProgressFor(String fileSource) =>
      repository.metadataProgressFor(fileSource);
  final _priorityRequests = StreamController<void>.broadcast();

  /// Fires when a visible item was moved to the front of the metadata queue.
  Stream<void> get priorityRequests => _priorityRequests.stream;

  /// Raises metadata priority for items the user is looking at (recent list,
  /// detail page, visible library entries). Already-processed items are no-ops.
  void prioritizeMetadata(Iterable<String> mediaIds) {
    if (_closeRequested || _databaseClosed) return;
    final ids = mediaIds.toSet().toList();
    if (ids.isEmpty) return;
    if (repository.prioritizeMetadata(ids) > 0 && !_priorityRequests.isClosed) {
      _priorityRequests.add(null);
    }
  }

  bool _notifyPending = false;

  void checkExternalChanges() {
    if (_closeRequested) return;
    final version = repository.dataVersion;
    if (version != _dataVersion) {
      _dataVersion = version;
      notifyChanged();
    }
  }

  void _closeDatabase() {
    if (_databaseClosed) return;
    _databaseClosed = true;
    _externalWatch?.cancel();
    _notifyTimer?.cancel();
    _priorityRequests.close();
    _changes.close();
    repository.close();
  }

  late final LibraryRepository repository;

  /// Compatibility access for metadata and assistant persistence. New library
  /// operations belong in LibraryRepository rather than issuing SQL here.
  Database get db => repository.db;

  /// `configuration.sqlite3`: the user's settings (ASR backends, external
  /// services, assistant model, metadata settings, file sources).
  Database get configuration => repository.configuration;
  MetadataRepository get metadata => repository.metadata;
  bool get isClosing => _closeRequested;
  void beginMetadataWork(String id) {
    if (_closeRequested) throw StateError(appStrings.errLibraryClosing);
    _running.add("metadata:$id");
  }

  void endMetadataWork(String id) {
    _running.remove("metadata:$id");
    if (_closeRequested && _running.isEmpty) _closeDatabase();
  }

  final Set<String> _running = {};
  bool _closeRequested = false;
  static String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  static Future<LibraryService> open({
    bool recoverInterrupted = true,
    bool watchExternalChanges = true,
    String databaseName = 'library.sqlite3',
  }) async {
    final db = await LibraryDatabase.open(databaseName);
    Database? configuration;
    try {
      configuration = await ConfigurationDatabase.open();
      return LibraryService(
        db,
        configuration: configuration,
        recoverInterrupted: recoverInterrupted,
        watchExternalChanges: watchExternalChanges,
      );
    } catch (_) {
      db.close();
      configuration?.close();
      rethrow;
    }
  }

  T transaction<T>(T Function() action) {
    _inTransaction = true;
    try {
      final result = repository.transaction(action);
      _inTransaction = false;
      notifyChanged();
      return result;
    } catch (_) {
      _inTransaction = false;
      rethrow;
    }
  }

  /// File sources (a connection plus one chosen folder) with their scan
  /// state: `id`, `source`, `root`, `name`, `enabled`, `status`, `error`.
  List<Map<String, Object?>> fileSources() => repository
      .fileSources()
      .where(
        (row) => repository.connectionVisibleToAccount(row['source'] as String),
      )
      .toList();

  /// [fileSources] as models.
  List<FileSource> fileSourceList() => [
    for (final row in fileSources()) FileSource.fromRow(row),
  ];

  void setFileSourceEnabled(String id, bool enabled) {
    repository.setFileSourceEnabled(id, enabled);
    notifyChanged();
  }

  void renameFileSource(String id, String name) {
    if (name.trim().isEmpty) throw ArgumentError(appStrings.errNameRequired);
    repository.renameFileSource(id, name.trim());
    notifyChanged();
  }

  /// Adds a file source on [source] (a connection), optionally limited to
  /// the folder [root]. Returns its id.
  String addFileSource(
    String source, {
    String? root,
    String? name,
    SourceEntry? rootEntry,
  }) {
    final id = _id();
    repository.insertFileSource(
      id,
      source,
      root,
      name?.trim().isEmpty == true ? null : name,
    );
    if (rootEntry?.media != null) {
      final media = register(rootEntry!);
      transaction(() => _observe(id, media));
    }
    notifyChanged();
    return id;
  }

  /// Reuses a confirmed scope, including disabled bindings, on retries.
  String addToHome(
    String source, {
    String? root,
    String? name,
    SourceEntry? entry,
  }) {
    final existing = fileSourceList()
        .where(
          (f) => f.connectionId == source && (f.root ?? '') == (root ?? ''),
        )
        .firstOrNull;
    if (existing != null) {
      if (!existing.enabled) setFileSourceEnabled(existing.id, true);
      return existing.id;
    }
    return addFileSource(source, root: root, name: name, rootEntry: entry);
  }

  /// Persist work before returning to the home page. The service owns its
  /// lifetime; errors remain in the binding's state for an in-place retry.
  void startScan(String id, SourceManager sources) {
    if (_closeRequested) throw StateError(appStrings.errLibraryClosing);
    if (_running.contains(id)) return;
    final binding = fileSourceList().firstWhere((f) => f.id == id);
    final config = sources.configs.firstWhere(
      (c) => c.id == binding.connectionId,
    );
    transaction(() {
      final prior = repository.scanTask(id).firstOrNull;
      if (prior == null || prior['revision'] != config.revision) {
        repository.removeScanTask(id);
        repository.insertScanTask(id, _id(), config.revision);
        repository.insertScanRoot(id, binding.root ?? '');
      }
      repository.markScanRunning(id);
    });
    unawaited(scan(id, sources).catchError((Object _) {}));
  }

  /// Restore interrupted traversal using its saved page cursor.
  Future<void> recoverScans(SourceManager sources) async {
    await sources.load();
    if (_closeRequested) return;
    for (final binding in fileSourceList()) {
      final config = sources.configs
          .where((c) => c.id == binding.connectionId)
          .firstOrNull;
      if (binding.enabled &&
          config?.enabled == true &&
          config!.scanMode != ScanMode.disabled &&
          (binding.status == ScanStatus.interrupted || binding.scanning) &&
          repository.scanTask(binding.id).isNotEmpty) {
        startScan(binding.id, sources);
      }
    }
  }

  String _content(SourceEntry entry) {
    final info = entry.media;
    if (info != null) {
      final known = repository
          .sourceMedia(entry.ref.instanceId, info.id)
          .firstOrNull;
      if (known != null) {
        final media = known['media_id'] as String;
        _serverMetadata(media, entry);
        return media;
      }
    }
    if (info != null && info.parentId != null) {
      final visited = <String>{info.id};
      String? parent = info.parentId;
      while (parent != null) {
        if (!visited.add(parent)) {
          throw PluginException('invalidInput', appStrings.errSeasonCycle);
        }
        parent =
            repository
                    .sourceParent(entry.ref.instanceId, parent)
                    .firstOrNull?['parent_key']
                as String?;
      }
    }
    final media = _id();
    repository.insertMedia(media, info?.title ?? entry.name);
    if (info != null) {
      repository.insertSourceMedia(
        entry.ref.instanceId,
        info.id,
        media,
        info.kind,
        info.parentId,
        info.year,
        info.season,
        info.episode,
      );
    }
    _serverMetadata(media, entry);
    return media;
  }

  void _serverMetadata(String media, SourceEntry entry) {
    final info = entry.media;
    if (info == null) return;
    final kind = MediaKind.values.where((k) => k.name == info.kind).firstOrNull;
    if (kind == null) return;
    final record = metadataFromSource(info, entry.ref.instanceId);
    final selected = metadata.association(media);
    if (selected != null && !metadata.compatible(record, selected)) return;
    metadata.apply(
      media,
      record,
      sourceKey: 'server:${entry.ref.instanceId}',
      authority: 300,
      expectedRevision: metadata.revision(media),
      operationId: _id(),
      select: selected == null,
    );
  }

  void _observe(String fileSource, String media) {
    repository.observeMedia(fileSource, media);
    repository.observeMembership(media, DateTime.now().millisecondsSinceEpoch);
    repository.queueMetadata(media, refresh: true);
  }

  List<Row> children(String media, {int offset = 0, int limit = 40}) =>
      repository.children(media, limit, offset);
  String register(SourceEntry entry, {String? localPath}) => transaction(() {
    final media = _register(entry, localPath: localPath);
    final size = entry.size;
    if (size != null && !entry.isFolder) {
      repository.setResourceSize(entry.ref.instanceId, entry.ref.id, size);
    }
    return media;
  });

  String _register(SourceEntry entry, {String? localPath}) {
    final existing = repository.mediaForLocator(
      entry.ref.instanceId,
      entry.ref.id,
    );
    if (existing.isNotEmpty) {
      final media = existing.first['media_id'] as String;
      _serverMetadata(media, entry);
      return media;
    }
    if (localPath != null) {
      final local = repository.localResource(localPath);
      if (local.isNotEmpty) {
        repository.ensureLocator(
          entry.ref.instanceId,
          entry.ref.id,
          local.first['id'] as String,
        );
        return local.first['media_id'] as String;
      }
    }
    final media = _content(entry);
    if (entry.isFolder) return media;
    final resource = _id();
    repository.insertResource(
      resource,
      media,
      entry.ref.instanceId,
      entry.ref.id,
      entry.name,
    );
    repository.insertLocator(entry.ref.instanceId, entry.ref.id, resource);
    if (localPath != null) {
      repository.insertLocalIdentity(localPath, resource);
    }
    return media;
  }

  /// Media whose files are all hidden dot files (macOS `._movie.mp4` sidecars,
  /// kept from scans before those were filtered) never show in the library.
  List<Row> query({
    String search = '',
    String? source,
    String? contentType,
    int? year,
    bool? watched,
    int offset = 0,
    int limit = 40,
  }) {
    if (offset < 0 || limit < 1 || limit > 200) {
      throw ArgumentError(appStrings.errInvalidPagingShort);
    }
    return repository.query(
      search: search,
      source: source,
      contentType: contentType,
      year: year,
      watched: watched,
      offset: offset,
      limit: limit,
    );
  }

  List<Row> resources(String media) => repository.resources(media);

  /// Files to play [media] from: every shown version of the same movie or
  /// episode, largest first.
  List<Row> versions(String media) => repository.versions(media);

  /// [versions] as models, largest first.
  List<MediaVersion> versionList(String media) => [
    for (final row in versions(media)) MediaVersion.fromRow(row),
  ];

  /// Children of [media] (seasons, episodes, extras) as models.
  List<MediaItem> childItems(String media, {int limit = 40}) => [
    for (final row in children(media, limit: limit)) MediaItem.fromRow(row),
  ];

  /// Other parts of [media]'s collection as models.
  List<MediaItem> collectionItems(String media) => [
    for (final row in collection(media)) MediaItem.fromRow(row),
  ];

  /// Watch progress of resource [resource], if it was ever played.
  WatchProgress? progressOf(String resource) => switch (checkpoint(resource)) {
    final row? => WatchProgress.fromRow(row),
    null => null,
  };

  /// Other library items in the same film collection (including [media]).
  List<Row> collection(String media) {
    final collection = metadata.fields(media)['collection'];
    final id = collection is Map ? collection['id'] : null;
    return id is String ? repository.collectionMembers(id) : const [];
  }

  /// The playable resources of a movie, or of every episode under a series.
  List<String> playableResources(String media) {
    final result = <String>[];
    final seen = <String>{};
    void visit(String id, int depth) {
      if (!seen.add(id)) return;
      result.addAll(resources(id).map((r) => r['id'] as String));
      if (depth >= 2) return;
      for (final child in children(id, limit: 500)) {
        visit(child['id'] as String, depth + 1);
      }
    }

    visit(media, 0);
    return result;
  }

  /// Every playable resource has been watched to the end.
  bool isWatched(String media) {
    final all = playableResources(media);
    return all.isNotEmpty && all.every((r) => checkpoint(r)?['completed'] == 1);
  }

  /// Marks a movie, or every episode of a series, as watched or unwatched.
  void setWatched(String media, bool watched) => transaction(() {
    for (final resource in playableResources(media)) {
      if (!watched) {
        repository.resetProgress(resource);
        continue;
      }
      final duration = checkpoint(resource)?['duration'];
      final length = duration is int && duration > 0 ? duration : 1;
      final session = beginSession(resource);
      repository.saveProgress(
        length,
        length,
        DateTime.now().millisecondsSinceEpoch,
        1,
        resource,
        session,
      );
    }
  });
  void rename(String media, String title) {
    if (title.trim().isEmpty) throw ArgumentError(appStrings.errTitleRequired);
    transaction(
      () => metadata.overrideField(
        media,
        'title',
        title.trim(),
        expectedRevision: metadata.revision(media),
      ),
    );
  }

  /// Hide a title from the poster wall; later scans do not bring it back.
  /// Files, media records and progress are untouched.
  void hide(String media) => transaction(() {
    // All versions, or the next one would stand in for the hidden title.
    for (final version in repository.versionGroup(media)) {
      repository.ignoreMedia(version);
      repository.removeMembership(version);
    }
  });
  void clearIgnored() => transaction(() => repository.clearAllIgnored());

  /// Browse explicitly selected scope, preserving source identities. Only a fully
  /// successful traversal marks old observations unavailable; failures retain data.
  Future<void> scan(String fileSource, SourceManager sources) async {
    if (!_running.add(fileSource)) throw StateError(appStrings.errScanRunning);
    var analyticsSuccess = false;
    final analyticsTimer = Stopwatch()..start();
    var analyticsCount = 0;
    var batch = _id();
    try {
      final b = repository.fileSource(fileSource);
      if (b == null) throw StateError(appStrings.errFileSourceMissing);
      if (b['enabled'] == 0) throw StateError(appStrings.errFileSourceDisabled);
      await sources.load();
      final source = b['source'] as String;
      final config = sources.configs.firstWhere((c) => c.id == source);
      if (!config.enabled || config.scanMode == ScanMode.disabled) {
        throw StateError(appStrings.errSourceScanDisabled);
      }
      var scanRoot = config.rootPath;
      if (config.kind == SourceKind.local) {
        try {
          scanRoot = await Directory(scanRoot).resolveSymbolicLinks();
        } catch (_) {}
      }
      final revision = config.revision;
      repository.markScanRunning(fileSource);
      final prior = repository.scanTask(fileSource).firstOrNull;
      if (prior != null && prior['revision'] == revision) {
        batch = prior['batch'] as String;
      } else {
        transaction(() {
          repository.removeScanTask(fileSource);
          repository.insertScanTask(fileSource, batch, revision);
          repository.insertScanRoot(fileSource, b['root'] as String? ?? '');
        });
      }
      var requests = 0;
      while (true) {
        final work = repository.nextScanNode(fileSource).firstOrNull;
        if (work == null) break;
        final nodeId = work['node'] as String;
        final node = nodeId.isEmpty ? null : ResourceRef(source, nodeId);
        final offset = work['offset'] as int;
        if (++requests > 10000) throw StateError(appStrings.errScanTooLarge);
        final page = await sources.browse(
          source,
          BrowseRequest(node: node, offset: offset),
        );
        await sources.reload();
        if (!sources.configs.any(
              (c) => c.id == source && c.enabled && c.revision == revision,
            ) ||
            !repository.fileSourceExists(fileSource)) {
          throw StateError(appStrings.errScanBindingChanged);
        }
        for (final entry in page.entries) {
          if (entry.ref.instanceId != source) {
            throw StateError(appStrings.errSourceIdentityMismatch);
          }
          final prefix = scanRoot;
          final normalized = entry.ref.id.replaceAll('\\', '/');
          final root = prefix
              .replaceAll('\\', '/')
              .replaceFirst(RegExp(r'/+$'), '');
          final relative = normalized.startsWith('$root/')
              ? normalized.substring(root.length + 1)
              : normalized;
          if (config.isFileSource && config.excludedFromScan(relative)) {
            continue;
          }
          if (entry.isFolder) {
            if (entry.media != null) {
              final container = register(entry);
              transaction(() => _observe(fileSource, container));
            }
            repository.enqueueScanNode(fileSource, entry.ref.id);
            continue;
          }
          if (config.isFileSource &&
              !entry.isDisc &&
              !matchesScanExtension(entry.name, sources.scanExtensions)) {
            continue;
          }
          analyticsCount++;
          final media = register(
            entry,
            localPath: config.kind == SourceKind.local ? entry.ref.id : null,
          );
          transaction(() {
            final resource =
                resourceFor(entry.ref)?['id'] ?? resources(media).first['id'];
            repository.observeResource(fileSource, resource as String, batch);
            _observe(fileSource, media);
          });
        }
        final next = page.nextOffset;
        if (next != null && next <= offset) {
          throw StateError(appStrings.errSourceCursorStuck);
        }
        repository.advanceScanNode(
          next ?? offset,
          next == null ? 1 : 0,
          fileSource,
          nodeId,
        );
      }
      transaction(() {
        repository.markUnseenResourcesMissing(fileSource, batch);
        repository.removeScanTask(fileSource);
        repository.markScanComplete(fileSource);
      });
      analyticsSuccess = true;
    } catch (error) {
      repository.markScanFailed(
        error is PluginException ? error.message : appStrings.errScanIncomplete,
        fileSource,
      );
      rethrow;
    } finally {
      _running.remove(fileSource);
      notifyChanged();
      unawaited(
        AnalyticsService.instance.capture('library_scan_completed', {
          'success': analyticsSuccess,
          'duration_ms': analyticsTimer.elapsedMilliseconds,
          'item_count': analyticsCount,
        }),
      );
      if (_closeRequested && _running.isEmpty) _closeDatabase();
    }
  }

  /// Valid media files the running scan of [fileSource] has found so far.
  int scannedMediaCount(String fileSource) =>
      repository.scannedMediaCount(fileSource).first['n'] as int;

  /// Available playable titles found by a scope, including completed scans.
  int fileSourceMediaCount(String id) => repository.fileSourceMediaCount(id);

  /// Title of media [id], if it exists.
  String? mediaTitle(String id) =>
      db.select('SELECT title FROM media WHERE id=?', [
            id,
          ]).firstOrNull?['title']
          as String?;

  Row? resourceFor(ResourceRef ref) =>
      repository.resourceFor(ref.instanceId, ref.id).firstOrNull;
  Row? checkpoint(String resource) =>
      repository.checkpoint(resource).firstOrNull;

  /// The subtitle last chosen for [resource] (encoded by the player).
  String? subtitleChoice(String resource) =>
      repository.subtitleChoice(resource).firstOrNull?['choice'] as String?;

  void saveSubtitleChoice(String resource, String choice) =>
      repository.saveSubtitleChoice(
        resource,
        choice,
        DateTime.now().millisecondsSinceEpoch,
      );

  String beginSession(String resource) {
    final session = _id();
    repository.beginSession(
      resource,
      session,
      DateTime.now().millisecondsSinceEpoch,
    );
    return session;
  }

  void saveProgress(
    String resource,
    String session,
    Duration position,
    Duration duration, {
    bool completed = false,
  }) {
    if (position.isNegative || duration <= Duration.zero) return;
    repository.saveProgress(
      position.inMilliseconds.clamp(0, duration.inMilliseconds),
      duration.inMilliseconds,
      DateTime.now().millisecondsSinceEpoch,
      completed ? 1 : 0,
      resource,
      session,
    );
  }

  List<Row> continueWatching({int limit = 20}) =>
      repository.continueWatching(limit);

  bool observedMissing(String resource) {
    final rows = repository.resourceObservations(resource);
    return rows.isNotEmpty && rows.every((r) => r['available'] == 0);
  }

  /// How many titles only [fileSource] found (shown before removing it).
  int fileSourceImpact(String fileSource) =>
      repository.fileSourceImpact(fileSource).first['n'] as int;

  /// Removes the file source and its scan results. Titles no other file
  /// source found, and that were not added by hand, leave the poster wall.
  /// File sources in the connection [source].
  List<String> fileSourcesOf(String source) => [
    for (final s in fileSources())
      if (s['source'] == source) s['id'] as String,
  ];

  /// Removes every file source of the deleted connection [source], with
  /// everything they brought into the library.
  void removeFileSourcesOf(String source) {
    for (final id in fileSourcesOf(source)) {
      removeFileSource(id);
    }
  }

  void removeFileSource(String fileSource) {
    transaction(() {
      final affected = repository.fileSourceMedia(fileSource);
      repository.deleteFileSourceData(fileSource);
      for (final media in affected) {
        repository.pruneUnobservedMembership(media['media_id'] as String);
      }
    });
    // Configuration last: if this fails the file source stays, without
    // results, and can be scanned or removed again.
    repository.deleteFileSource(fileSource);
    notifyChanged();
  }

  void close() {
    if (_closeRequested) return;
    _closeRequested = true;
    _externalWatch?.cancel();
    for (final subscription in _followed.values) {
      unawaited(subscription.cancel());
    }
    _followed.clear();
    if (_running.isEmpty) _closeDatabase();
  }
}
