import 'dart:convert';

import '../../core/plugins/metadata_capability.dart';
import '../../core/plugins/source_capability.dart';
import '../../data/metadata/metadata_repository.dart';
import '../../data/sources/source_manager.dart';
import '../../plugins/metadata_nfo/nfo_metadata_plugin.dart';
import '../library/library_service.dart';
import 'media_name_parser.dart';

/// Metadata operations shared by manual editing and the library background queue.
/// The queue owns automatic matching policy; interactive searches keep candidates.
class MetadataService {
  MetadataService(
    this.library,
    this.sources, {
    MetadataRegistry? registry,
    this.canApply,
  }) : registry = registry ?? MetadataRegistry() {
    this.registry.register('nfo', NfoMetadataPlugin(sources.readAttachment));
    _providerRevision = repository.setting('tmdbRevision');
  }
  final bool Function(String media)? canApply;
  final LibraryService library;
  final SourceManager sources;
  final MetadataRegistry registry;
  MetadataRepository get repository => library.metadata;
  final _cancelled = <String>{};
  final _active = <String>{};
  bool _stopBatch = false;
  void cancelActive() {
    _stopBatch = true;
    for (final id in _active.toList()) {
      cancel(id);
    }
  }

  bool _disposed = false;
  late final String _providerRevision;
  Map<String, dynamic> _snapshot(String media) => {
    'language': language,
    'nameEvidence': {
      'rule': MediaNameEvidence.ruleVersion,
      'title': evidence(media).title,
      'year': evidence(media).year,
      'season': evidence(media).season,
      'episodes': evidence(media).episodes,
      'tags': evidence(media).tags,
    },
    'providerRevision': repository.setting('tmdbRevision'),
    'sourceRevisions': {
      for (final r in library.resources(media))
        if (sources.configs.any((c) => c.id == r['source']))
          r['source'] as String: sources.configs
              .firstWhere((c) => c.id == r['source'])
              .revision,
    },
  };
  bool _snapshotCurrent(String id) {
    final input = jsonDecode(
      repository.job(id)['input'] as String,
    ) as Map<String, dynamic>;
    final revisions = input['sourceRevisions'] as Map? ?? {};
    return (!input.containsKey('language') || input['language'] == language) &&
        (!input.containsKey('providerRevision') ||
            input['providerRevision'] == repository.setting('tmdbRevision')) &&
        revisions.entries.every(
          (r) => sources.configs.any(
            (c) => c.id == r.key && c.enabled && c.revision == r.value,
          ),
        );
  }

  Future<void> _validate(String id) async {
    await sources.reload();
    _check(id);
  }

  String get language => repository.setting('language', fallback: 'zh-CN');
  MediaNameEvidence evidence(String media) {
    final files = library.resources(media);
    final fields = repository.fields(media);
    final name =
        files.firstOrNull?['name'] as String? ??
        fields['title'] as String? ??
        '';
    final known = MediaKind.values
        .where((k) => k.name == fields['kind'])
        .firstOrNull;
    return const MediaNameParser().parse(name, kind: known);
  }

  bool _current(String id) =>
      !_disposed &&
      !library.isClosing &&
      !_cancelled.contains(id) &&
      (canApply?.call(repository.job(id)['media_id'] as String) ?? true) &&
      _snapshotCurrent(id) &&
      repository.job(id)['revision'] ==
          repository.revision(repository.job(id)['media_id'] as String);
  void _check(String id) {
    if (!_current(id)) throw const PluginException('cancelled', '查询已过期或已取消');
  }

  void cancel(String id) {
    _cancelled.add(id);
    if (!library.isClosing) repository.stage(id, 'cancelled');
  }

  Future<T> _run<T>(String id, Future<T> Function() action) async {
    library.beginMetadataWork(id);
    _active.add(id);
    try {
      _check(id);
      return await action();
    } catch (error) {
      final code = error is PluginException ? error.code : 'invalidMetadata';
      repository.stage(
        id,
        code == 'cancelled' || code == 'conflict' ? 'cancelled' : 'failed',
        error: code,
      );
      rethrow;
    } finally {
      _active.remove(id);
      library.endMetadataWork(id);
    }
  }

  Future<String> search(
    String media, {
    required String query,
    MediaKind kind = MediaKind.movie,
    int? year,
    String? providerId,
    int page = 1,
  }) async {
    if (_providerRevision != repository.setting('tmdbRevision')) {
      throw const PluginException('cancelled', 'TMDB 配置已改变');
    }
    final id = repository.createJob(media, {
      ..._snapshot(media),
      'query': query,
      'kind': kind.name,
      'year': year,
      'language': language,
      'page': page,
      'providerId': providerId,
    });
    await _run(id, () async {
      repository.stage(id, 'searching');
      final result = await registry.lookup(
        'tmdb',
        providerId == null
            ? MetadataRequest(
                action: MetadataAction.search,
                kind: kind,
                query: query,
                year: year,
                language: language,
                page: page,
              )
            : MetadataRequest(
                action: MetadataAction.details,
                kind: kind,
                ref: MetadataRef('tmdb', kind, providerId),
                language: language,
              ),
      );
      await _validate(id);
      final input = jsonDecode(
        repository.job(id)['input'] as String,
      ) as Map<String, dynamic>;
      library.db.execute('UPDATE metadata_jobs SET input=? WHERE id=?', [
        jsonEncode({...input, 'nextPage': result.nextPage}),
        id,
      ]);
      repository.stage(
        id,
        result.records.isEmpty ? 'unmatched' : 'awaitingSelection',
        candidates: result.records,
      );
    });
    return id;
  }

  Future<void> confirm(
    String id,
    MetadataRef selected, {
    bool userConfirmed = true,
  }) async {
    final job = repository.job(id);
    if (job['stage'] != 'awaitingSelection') {
      throw const PluginException('conflict', '请重新查询候选');
    }
    final requiredKind = evidence(job['media_id'] as String).kind;
    if ([MediaKind.episode, MediaKind.season].contains(requiredKind) &&
        selected.kind != requiredKind) {
      throw const PluginException('invalidInput', '请先选择具体季集');
    }
    final candidates = (jsonDecode(job['candidates'] as String) as List)
        .map((e) => MetadataRecord.fromJson(e))
        .toList();
    if (!candidates.any((c) => c.ref.key == selected.key)) {
      throw const PluginException('invalidInput', '候选不属于此查询');
    }
    await _run(id, () async {
      repository.stage(id, 'fetching');
      final result = await registry.lookup(
        'tmdb',
        MetadataRequest(
          action: MetadataAction.details,
          kind: selected.kind,
          ref: selected,
          language: language,
        ),
      );
      await _validate(id);
      if (result.records.length != 1 ||
          result.records.single.ref.key != selected.key) {
        throw const PluginException('invalidMetadata', '详情身份不匹配');
      }
      final media = job['media_id'] as String;
      final ancestors = await _onlineAncestors(media, selected);
      await _validate(id);
      library.transaction(() {
        _check(id);
        repository.stage(id, 'applying');
        repository.apply(
          media,
          result.records.single,
          sourceKey: 'tmdb',
          authority: 100,
          expectedRevision: job['revision'] as int,
          operationId: id,
          select: true,
          userConfirmed: userConfirmed,
        );
        library.db.execute('DELETE FROM metadata_relations WHERE child_id=?', [
          media,
        ]);
        repository.attachHierarchy(media, ancestors, operationId: id);
        repository.stage(id, 'completed');
      });
    });
  }

  Future<void> chooseLocal(String id, int index) async {
    final job = repository.job(id);
    if (job['stage'] != 'awaitingSelection') {
      throw const PluginException('conflict', '请重新加载候选');
    }
    final records = (jsonDecode(job['candidates'] as String) as List)
        .map((e) => MetadataRecord.fromJson(e))
        .toList();
    if (index < 0 ||
        index >= records.length ||
        !records[index].ref.provider.startsWith('nfo:')) {
      throw const PluginException('invalidInput', '无效的本地候选');
    }
    await _run(id, () async {
      final media = job['media_id'] as String;
      final record = records[index];
      library.transaction(() {
        _check(id);
        repository.apply(
          media,
          record,
          sourceKey: 'nfo:${record.ref.provider.substring(4)}:${record.ref.id}',
          authority: 200,
          expectedRevision: job['revision'] as int,
          operationId: id,
          select: true,
          userConfirmed: true,
          selectedRef: record.externalIds.firstOrNull ?? record.ref,
        );
        repository.stage(id, 'completed');
      });
    });
  }

  Future<void> children(String id, MetadataRef selected) async {
    final job = repository.job(id);
    final candidates = (jsonDecode(job['candidates'] as String) as List).map(
      (e) => MetadataRecord.fromJson(e),
    );
    if (job['stage'] != 'awaitingSelection' ||
        !candidates.any((c) => c.ref.key == selected.key)) {
      throw const PluginException('invalidInput', '请先选择剧集');
    }
    await _run(id, () async {
      repository.stage(id, 'fetching');
      final result = await registry.lookup(
        'tmdb',
        MetadataRequest(
          action: MetadataAction.children,
          kind: selected.kind,
          ref: selected,
          language: language,
        ),
      );
      await _validate(id);
      repository.stage(
        id,
        result.records.isEmpty ? 'unmatched' : 'awaitingSelection',
        candidates: result.records,
      );
    });
  }

  Future<void> refresh(String media) async {
    final ref = repository.association(media);
    if (ref == null) throw const PluginException('invalidInput', '请先确认匹配');
    final server = ref.provider.startsWith('server:');
    if (!server &&
        (ref.provider != 'tmdb' ||
            ([MediaKind.season, MediaKind.episode].contains(ref.kind) &&
                ref.seriesId == null))) {
      await importSidecars(media);
      return;
    }
    final source = server ? ref.provider.substring(7) : null;
    final id = repository.createJob(media, {
      ..._snapshot(media),
      'refresh': ref.toJson(),
      if (source != null)
        'sourceRevisions': {
          source: sources.configs.firstWhere((c) => c.id == source).revision,
        },
    });
    await _run(id, () async {
      repository.stage(id, 'fetching');
      final request = MetadataRequest(
        action: MetadataAction.details,
        kind: ref.kind,
        ref: ref,
        language: language,
      );
      final result = server
          ? await sources.lookupMetadata(source!, request)
          : await registry.lookup('tmdb', request);
      await _validate(id);
      if (result.records.length != 1 ||
          result.records.single.ref.key != ref.key) {
        throw const PluginException('invalidMetadata', '详情身份不匹配');
      }
      library.transaction(() {
        _check(id);
        repository.stage(id, 'applying');
        repository.apply(
          media,
          result.records.single,
          sourceKey: server ? 'server:$source' : 'tmdb',
          authority: server ? 300 : 100,
          expectedRevision: repository.job(id)['revision'] as int,
          operationId: id,
        );
        repository.stage(id, 'completed');
      });
    });
  }

  Future<List<SourceEntry>> _directory(ResourceRef parent) async {
    final entries = <SourceEntry>[];
    int? offset = 0;
    do {
      final page = await sources.browse(
        parent.instanceId,
        BrowseRequest(node: parent, offset: offset!, limit: 200),
      );
      entries.addAll(page.entries);
      if (entries.length > 10000) {
        throw const PluginException('quotaExceeded', '目录过大，请缩小元数据范围');
      }
      if (page.nextOffset != null && page.nextOffset! <= offset) {
        throw const PluginException('invalidMetadata', '分页游标未前进');
      }
      offset = page.nextOffset;
    } while (offset != null);
    return entries;
  }

  MetadataRecord _adjacentArtwork(
    MetadataRecord record,
    List<SourceEntry> entries,
    String stem, {
    required bool directoryOwned,
  }) {
    final artwork = [...record.artwork];
    for (final file in entries.where((e) => !e.isFolder)) {
      final name = file.name.toLowerCase();
      final prefix = stem.toLowerCase();
      final type =
          name.startsWith('$prefix-poster.') ||
              directoryOwned && name.startsWith('poster.')
          ? 'poster'
          : name.startsWith('$prefix-fanart.') ||
                directoryOwned && name.startsWith('fanart.')
          ? 'backdrop'
          : name.startsWith('$prefix-thumb.')
          ? 'thumbnail'
          : null;
      if (type != null &&
          RegExp(r'\.(jpg|jpeg|png|webp)$').hasMatch(name) &&
          !artwork.any((a) => a.source?.id == file.ref.id)) {
        artwork.add(
          ArtworkDescriptor(
            id: '${file.ref.instanceId}:${file.ref.id}',
            type: type,
            source: file.ref,
          ),
        );
      }
    }
    return MetadataRecord(
      ref: record.ref,
      fields: record.fields,
      language: record.language,
      externalIds: record.externalIds,
      artwork: artwork,
      warnings: record.warnings,
      contentRevision: record.contentRevision,
    );
  }

  Future<List<({String scope, MetadataRecord record})>> _localAncestors(
    String media,
    MetadataRecord item,
    ResourceRef directory,
  ) async {
    if (![MediaKind.episode, MediaKind.season].contains(item.ref.kind)) {
      return [];
    }
    final config = sources.configs.firstWhere(
      (c) => c.id == directory.instanceId,
    );
    var root = config.rootPath;
    // Folders of the file sources on this connection that found [media].
    final found = {
      for (final r in library.db.select(
        'SELECT DISTINCT e.file_source_id FROM evidence e JOIN resources r ON r.id=e.resource_id WHERE r.media_id=?',
        [media],
      ))
        r['file_source_id'],
    };
    final fileSourceRoots = library.fileSources().where(
      (f) => f['source'] == directory.instanceId && found.contains(f['id']),
    );
    for (final row in fileSourceRoots) {
      final candidate = row['root'] as String?;
      if (candidate != null &&
          candidate.length > root.length &&
          directory.id.startsWith(candidate)) {
        root = candidate;
      }
    }
    root = root.replaceFirst(RegExp(r'/+$'), '');
    var path = directory.id.replaceFirst(RegExp(r'/+$'), '');
    MetadataRecord? show, season;
    String? showKey, seasonKey;
    for (var level = 0; level < 3; level++) {
      if (path != root && !path.startsWith('$root/')) break;
      final entries = await _directory(
        ResourceRef(directory.instanceId, path.isEmpty ? '/' : path),
      );
      for (final name in ['tvshow.nfo', 'season.nfo']) {
        final file = entries
            .where((e) => !e.isFolder && e.name.toLowerCase() == name)
            .firstOrNull;
        if (file == null) continue;
        final result = await registry.lookup(
          'nfo',
          MetadataRequest(
            action: MetadataAction.details,
            kind: name == 'tvshow.nfo' ? MediaKind.series : MediaKind.season,
            attachment: file.ref,
          ),
        );
        var record = result.records.single;
        if (record.ref.kind !=
            (name == 'tvshow.nfo' ? MediaKind.series : MediaKind.season)) {
          continue;
        }
        record = _adjacentArtwork(
          record,
          entries,
          name.substring(0, name.length - 4),
          directoryOwned: true,
        );
        if (name == 'tvshow.nfo') {
          show = record;
          showKey = 'nfo:${directory.instanceId}:${file.ref.id}';
        } else if (season == null) {
          season = record;
          seasonKey = 'nfo:${directory.instanceId}:${file.ref.id}';
        }
      }
      if (show != null || path == root) break;
      final slash = path.lastIndexOf('/');
      if (slash < 0) break;
      path = path.substring(0, slash);
    }
    if (show == null) return [];
    final number = item.fields['season'] as int?;
    if (item.ref.kind == MediaKind.episode &&
        season == null &&
        number != null &&
        number >= 0) {
      seasonKey = '$showKey:season:$number';
      season = MetadataRecord(
        ref: MetadataRef(
          'local:${directory.instanceId}',
          MediaKind.season,
          seasonKey,
          season: number,
        ),
        fields: {
          'title': '${show.title} · S${number.toString().padLeft(2, '0')}',
          'kind': 'season',
          'season': number,
        },
      );
    }
    return [
      (scope: showKey!, record: show),
      if (season != null && item.ref.kind == MediaKind.episode)
        (scope: seasonKey!, record: season),
    ];
  }

  Future<List<({String scope, MetadataRecord record})>> _onlineAncestors(
    String media,
    MetadataRef ref,
  ) async {
    if (ref.seriesId == null ||
        ![MediaKind.episode, MediaKind.season].contains(ref.kind)) {
      return [];
    }
    final source =
        library.resources(media).firstOrNull?['source'] as String? ?? 'local';
    final show = (await registry.lookup(
      'tmdb',
      MetadataRequest(
        action: MetadataAction.details,
        kind: MediaKind.series,
        ref: MetadataRef('tmdb', MediaKind.series, ref.seriesId!),
        language: language,
      ),
    )).records.single;
    final ancestors = <({String scope, MetadataRecord record})>[
      (scope: 'tmdb:$source:${show.ref.key}', record: show),
    ];
    if (ref.kind == MediaKind.episode) {
      final seasonRef = show.children
          .where((s) => s.ref.season == ref.season)
          .firstOrNull
          ?.ref;
      if (seasonRef == null) {
        throw const PluginException('invalidMetadata', '单集所属季不存在');
      }
      final season = (await registry.lookup(
        'tmdb',
        MetadataRequest(
          action: MetadataAction.details,
          kind: MediaKind.season,
          ref: seasonRef,
          language: language,
        ),
      )).records.single;
      ancestors.add((scope: 'tmdb:$source:${season.ref.key}', record: season));
    }
    return ancestors;
  }

  Future<void> importSidecars(String media) async {
    for (final resource in library.resources(media)) {
      final source = resource['source'] as String;
      final config = sources.configs.where((c) => c.id == source).firstOrNull;
      // Direct-open resources carry no directory grant and never trigger scraping.
      if (config == null || !config.isFileSource || !config.enabled) continue;
      final item = resource['item'] as String;
      final slash = item.lastIndexOf('/');
      if (slash < 0) continue;
      final id = repository.createJob(media, {
        'sidecars': source,
        'sourceRevision': config.revision,
      });
      await _run(id, () async {
        repository.stage(id, 'collecting');
        final entries = await _directory(
          ResourceRef(source, item.substring(0, slash + 1)),
        );
        final stem = (resource['name'] as String).replaceFirst(
          RegExp(r'\.[^.]+$'),
          '',
        );
        final exact = entries
            .where(
              (e) =>
                  !e.isFolder &&
                  e.name.toLowerCase() == '${stem.toLowerCase()}.nfo',
            )
            .firstOrNull;
        final single =
            entries
                .where(
                  (e) =>
                      !e.isFolder &&
                      RegExp(
                        r'\.(mkv|mp4|avi|mov|m4v|ts|m2ts|webm|wmv)$',
                        caseSensitive: false,
                      ).hasMatch(e.name),
                )
                .length ==
            1;
        final generic = single && evidence(media).kind == MediaKind.movie
            ? entries
                  .where(
                    (e) => !e.isFolder && e.name.toLowerCase() == 'movie.nfo',
                  )
                  .firstOrNull
            : null;
        final nfo = exact ?? generic;
        final keys = <String>[];
        final records = <MetadataRecord>[];
        PluginException? parseFailure;
        for (final file in {
          ?nfo,
          if (exact != null && generic != null) generic,
        }) {
          try {
            final result = await registry.lookup(
              'nfo',
              MetadataRequest(
                action: MetadataAction.details,
                kind: evidence(media).kind,
                attachment: file.ref,
              ),
            );
            records.add(result.records.single);
            keys.add('nfo:$source:${file.ref.id}');
          } on PluginException catch (error) {
            parseFailure = error;
          }
        }
        if (records.isEmpty && parseFailure != null) throw parseFailure;
        _check(id);
        await sources.reload();
        if (!sources.configs.any(
          (c) => c.id == source && c.enabled && c.revision == config.revision,
        )) {
          throw const PluginException('cancelled', '来源配置已改变');
        }
        _check(id);
        if (records.isEmpty) {
          // Keep last imported fields, visibly mark vanished NFO sources.
          for (final row in library.db.select(
            "SELECT source_key FROM metadata_observations WHERE media_id=? AND source_key LIKE 'nfo:%'",
            [media],
          )) {
            repository.markMissing(media, row['source_key'] as String);
          }
          final parsed = evidence(media);
          final selected = repository.association(media);
          final fallback = MetadataRecord(
            ref: MetadataRef(
              'local:$source',
              selected?.kind ?? parsed.kind,
              item,
            ),
            fields: {
              'kind': (selected?.kind ?? parsed.kind).name,
              if (parsed.season != null) 'season': parsed.season,
              if (parsed.episodes.isNotEmpty) 'episode': parsed.episodes.first,
            },
            externalIds: [?selected],
          );
          final enriched = _adjacentArtwork(
            fallback,
            entries,
            stem,
            directoryOwned: single,
          );
          final parents = await _localAncestors(
            media,
            enriched,
            ResourceRef(source, item.substring(0, slash + 1)),
          );
          _check(id);
          if (enriched.artwork.isEmpty && parents.isEmpty) {
            repository.stage(id, 'unmatched');
            return;
          }
          records.add(enriched);
          keys.add('filename:$source:$item');
        }
        var record = records.first;
        final selected = repository.association(media);
        final identity =
            record.externalIds.where((r) => r.provider == 'tmdb').firstOrNull ??
            record.externalIds.firstOrNull ??
            record.ref;
        bool conflicts(MetadataRecord a, MetadataRecord b) => a.externalIds.any(
          (i) => b.externalIds.any(
            (j) =>
                i.provider == j.provider && i.kind == j.kind && i.key != j.key,
          ),
        );
        final parsed = evidence(media);
        final kindConflict =
            parsed.episodes.isNotEmpty && record.ref.kind != MediaKind.episode;
        if (kindConflict ||
            records.skip(1).any((r) => conflicts(record, r)) ||
            (selected != null &&
                !repository.compatible(record, selected) &&
                !(selected.provider.startsWith('nfo:') &&
                    !repository.confirmed(media)))) {
          repository.stage(
            id,
            'awaitingSelection',
            error: 'identityConflict',
            candidates: records,
          );
          return;
        }
        record = _adjacentArtwork(
          record,
          entries,
          stem,
          directoryOwned: single,
        );
        final ancestors = await _localAncestors(
          media,
          record,
          ResourceRef(source, item.substring(0, slash + 1)),
        );
        await sources.reload();
        if (!sources.configs.any(
          (c) => c.id == source && c.enabled && c.revision == config.revision,
        )) {
          throw const PluginException('cancelled', '来源配置已改变');
        }
        _check(id);
        library.transaction(() {
          _check(id);
          if (selected == null ||
              selected.provider.startsWith('nfo:') &&
                  !repository.confirmed(media)) {
            library.db.execute(
              'UPDATE metadata_state SET association=? WHERE media_id=?',
              [jsonEncode(identity.toJson()), media],
            );
          }
          repository.apply(
            media,
            record,
            sourceKey: keys.first,
            authority: keys.first.startsWith('filename:') ? 0 : 200,
            expectedRevision: repository.job(id)['revision'] as int,
            operationId: id,
          );
          repository.attachHierarchy(media, ancestors, operationId: id);
          repository.stage(id, 'completed', candidates: [record]);
        });
      });
    }
  }

  /// Explicit batch command. Each item commits independently and retries remain
  /// bounded by provider transport.
  Future<Map<String, int>> importLibrary({
    void Function(int, int)? onProgress,
  }) async {
    final lease = 'batch:${DateTime.now().microsecondsSinceEpoch}';
    library.beginMetadataWork(lease);
    try {
      final rows = library.db.select('SELECT media_id FROM memberships');
      _stopBatch = false;
      var completed = 0, failed = 0, waiting = 0, unmatched = 0;
      for (final row in rows) {
        if (_disposed || library.isClosing || _stopBatch) break;
        final media = row['media_id'] as String;
        try {
          await importSidecars(media);
          if (repository.latestJob(media)?['stage'] == 'awaitingSelection') {
            waiting++;
          } else if (repository.latestJob(media)?['stage'] == 'completed') {
            completed++;
          } else {
            unmatched++;
          }
        } catch (_) {
          failed++;
        }
        onProgress?.call(completed + failed + waiting + unmatched, rows.length);
      }
      return {
        'completed': completed,
        'failed': failed,
        'waiting': waiting,
        'unmatched': unmatched,
      };
    } finally {
      library.endMetadataWork(lease);
    }
  }

  Future<void> dispose() async {
    cancelActive();
    _disposed = true;
    await registry.dispose();
  }
}
