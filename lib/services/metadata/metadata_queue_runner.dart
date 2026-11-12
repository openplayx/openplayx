import 'dart:convert';
import 'dart:math';

import 'tmdb_credentials.dart';

import '../../core/plugins/metadata_capability.dart';
import '../../core/plugins/source_capability.dart';
import '../../data/metadata/metadata_queue.dart';
import '../../data/sources/source_manager.dart';
import '../../plugins/metadata_tmdb/tmdb_metadata_plugin.dart';
import '../artwork/artwork_service.dart';
import '../library/library_service.dart';
import 'media_name_parser.dart';
import 'metadata_service.dart';

typedef MetadataCredentialReader = Future<String?> Function();

/// A bounded runner, usable by Android WorkManager and foreground desktop hosts.
/// It owns no widgets and never obtains a video playback URL.
class MetadataQueueRunner {
  MetadataQueueRunner(
    this.library,
    this.sources, {
    MetadataRegistry? registry,
    MetadataCredentialReader? credentials,
    ArtworkService? artwork,
  }) : queue = MetadataQueue(library.db),
       // ignore: prefer_initializing_formals
       _registry = registry,
       _credentials =
           credentials ??
           (() => tmdbCredentialStorage.read(
             key: 'openplayx.metadata.tmdb.token',
           )),
       artwork =
           artwork ??
           ArtworkService(
             sources,
             retainedArtwork: () => library.metadata.retainedArtwork,
           );
  final LibraryService library;
  final SourceManager sources;
  final MetadataQueue queue;
  final ArtworkService artwork;
  final MetadataRegistry? _registry;
  final MetadataCredentialReader _credentials;
  MetadataService? _service;
  bool _configured = false;
  bool _stopped = false;
  String? _owner;
  String? _activeMedia;
  static const matchRule = 'exact-title-year-v1';

  Future<int> reconcile() async {
    await sources.load();
    if (library.isClosing || _stopped) return 0;
    final inputs = <String, String>{};
    // Load everything in three queries instead of two per media; this runs on
    // the UI isolate, so per-media round trips scale badly with library size.
    final resourcesByMedia = <String, List<List<Object?>>>{};
    final revisions = {for (final c in sources.configs) c.id: c.revision};
    for (final r in library.db.select(
      'SELECT r.media_id,r.id,l.source,l.item,r.name FROM resources r JOIN resource_locators l ON l.resource_id=r.id ORDER BY r.media_id,r.id,l.source,l.item',
    )) {
      (resourcesByMedia[r['media_id'] as String] ??= []).add([
        r['id'],
        r['source'],
        r['item'],
        r['name'],
        revisions[r['source']],
      ]);
    }
    final kindsByMedia = <String, List<Object?>>{};
    for (final r in library.db.select(
      'SELECT m.media_id,l.type FROM memberships m JOIN libraries l ON l.id=m.library_id ORDER BY m.media_id,l.id',
    )) {
      (kindsByMedia[r['media_id'] as String] ??= []).add(r['type']);
    }
    final language = library.metadata.setting('language');
    final tmdbRevision = library.metadata.setting('tmdbRevision');
    for (final media in kindsByMedia.keys) {
      inputs[media] = MetadataQueue.fingerprint([
        resourcesByMedia[media] ?? const <List<Object?>>[],
        kindsByMedia[media]!,
        language,
        tmdbRevision,
      ]);
    }
    return queue.reconcile(inputs);
  }

  Future<MetadataService> _metadata({required bool allowOnline}) async {
    if (_service != null) {
      if (allowOnline && !_configured) {
        String? token;
        try {
          token = await _credentials();
        } catch (_) {}
        if (token?.trim().isNotEmpty == true) {
          final transport = TmdbTransport(token!.trim());
          _service!.registry.register(
            'tmdb',
            TmdbMetadataPlugin(transport.get, onDispose: transport.close),
          );
          _configured = true;
        }
      }
      return _service!;
    }
    final registry = _registry ?? MetadataRegistry();
    if (registry.contains('tmdb')) {
      _configured = true;
    } else if (allowOnline) {
      String? token;
      try {
        token = await _credentials();
      } catch (_) {
        /* Local import remains available. */
      }
      if (token?.trim().isNotEmpty == true) {
        final transport = TmdbTransport(token!.trim());
        registry.register(
          'tmdb',
          TmdbMetadataPlugin(transport.get, onDispose: transport.close),
        );
        _configured = true;
      }
    }
    _service = MetadataService(
      library,
      sources,
      registry: registry,
      canApply: (media) =>
          !_stopped &&
          _owner != null &&
          _activeMedia == media &&
          queue.owns(media, _owner!),
    );
    return _service!;
  }

  Future<void> runBatch({
    bool allowOnline = true,
    int maxItems = 12,
    Duration budget = const Duration(minutes: 3),
  }) async {
    if (_stopped || library.isClosing || _owner != null) return;
    final owner =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    _owner = owner;
    library.beginMetadataWork(owner);
    final until = DateTime.now().add(budget);
    try {
      for (
        var index = 0;
        index < maxItems && DateTime.now().isBefore(until);
        index++
      ) {
        if (_stopped || library.isClosing) break;
        final work = queue.claim(owner, allowOnline: allowOnline);
        if (work == null) break;
        final media = work['media_id'] as String;
        _activeMedia = media;
        try {
          await _process(
            media,
            owner,
            work['phase'] as int,
            allowOnline: allowOnline,
          );
        } catch (error) {
          if (queue.owns(media, owner)) {
            final failure = error is PluginException
                ? error
                : const PluginException(
                    'metadataFailed',
                    '后台识别失败',
                    retryable: true,
                  );
            final retryable =
                failure.retryable ||
                [
                  'networkUnavailable',
                  'timeout',
                  'rateLimited',
                  'conflict',
                  'cancelled',
                ].contains(failure.code);
            final attempts = queue.item(media)!['attempts'] as int;
            queue.finish(
              media,
              owner,
              failure.code == 'authRequired'
                  ? 'waitingConfiguration'
                  : retryable
                  ? 'queued'
                  : 'failed',
              error: failure.code,
              retryable: retryable,
              delay: Duration(seconds: 15 * (1 << attempts.clamp(0, 5))),
            );
          }
        } finally {
          _activeMedia = null;
          library.notifyChanged();
        }
      }
    } finally {
      queue.release(owner);
      _owner = null;
      _activeMedia = null;
      library.endMetadataWork(owner);
    }
  }

  bool _valid(String media, String owner) =>
      !_stopped && !library.isClosing && queue.owns(media, owner);
  Future<void> _images(String media, String owner) async {
    final selected = [
      for (final type in ['poster', 'backdrop', 'thumbnail'])
        library.metadata.selectedArtwork(media, type: type),
    ].whereType<ArtworkDescriptor>();
    for (final image in selected) {
      if (!_valid(media, owner)) return;
      await artwork.load(image);
    }
    // Pre-fetch the title logo too (and vet its transparency) so the detail
    // page can show it on first open. The UI may use a different language;
    // that pick is then resolved lazily.
    final logos = ArtworkService.orderedLogos(
      library.metadata.artworkCandidates(media),
      library.metadata.setting('language'),
    );
    if (logos.isNotEmpty && _valid(media, owner)) {
      await artwork.resolveLogo(logos);
    }
  }

  List<MetadataRecord> _candidates(String job) =>
      (jsonDecode(library.metadata.job(job)['candidates'] as String) as List)
          .map((e) => MetadataRecord.fromJson(e))
          .toList();
  static String _name(String title) => title.toLowerCase().replaceAll(
    RegExp(r'[\s._\-\[\](){}:：·,!！?？、，。]'),
    '',
  );
  static MetadataRecord? uniqueMatch(
    MediaNameEvidence evidence,
    List<MetadataRecord> candidates, {
    bool completePage = true,
  }) {
    if (!completePage || _name(evidence.title).isEmpty) return null;
    final matches = candidates
        .where(
          (c) =>
              [
                _name(c.title),
                _name(c.fields['originalTitle'] as String? ?? ''),
              ].contains(_name(evidence.title)) &&
              (evidence.year == null || c.fields['year'] == evidence.year),
        )
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  Future<void> _process(
    String media,
    String owner,
    int phase, {
    required bool allowOnline,
  }) async {
    final libraries = library.db.select(
      'SELECT l.type FROM memberships m JOIN libraries l ON l.id=m.library_id WHERE m.media_id=?',
      [media],
    );
    final resources = library.resources(media);
    if (libraries.isEmpty) return;
    if (libraries.every((l) => ['home', 'audio'].contains(l['type'])) ||
        resources.isNotEmpty &&
            resources.every(
              (r) => RegExp(
                r'\.(mp3|flac|wav|ogg|m4a)$',
                caseSensitive: false,
              ).hasMatch(r['name'] as String),
            )) {
      queue.finish(media, owner, 'skipped', error: 'notFilmMedia');
      return;
    }
    final service = await _metadata(allowOnline: allowOnline);
    if (!_valid(media, owner)) return;
    var selected = library.metadata.association(media);
    if (phase != 1 && resources.isNotEmpty) {
      final needsNetwork = resources.any(
        (r) => sources.configs.any(
          (c) => c.id == r['source'] && c.kind.name == 'smb',
        ),
      );
      if (!allowOnline && needsNetwork) {
        queue.finish(media, owner, 'queued', phase: 2);
        return;
      }
      await service.importSidecars(media);
      if (!_valid(media, owner)) return;
      final local = library.metadata.latestJob(media);
      if (local?['stage'] == 'awaitingSelection') {
        queue.finish(
          media,
          owner,
          'awaitingSelection',
          error: local?['error_code'] as String?,
          job: local?['id'] as String?,
        );
        return;
      }
      selected = library.metadata.association(media);
    }
    if (selected != null &&
        (selected.provider.startsWith('server:') ||
            selected.provider.startsWith('nfo:') ||
            selected.provider.startsWith('local:') ||
            library.metadata
                .observations(media)
                .any(
                  (r) =>
                      r.ref.provider.startsWith('nfo:') &&
                      library.metadata.compatible(r, selected!),
                ))) {
      // Reuse existing server/NFO organization, without launching a title search.
      final fields = library.metadata.fields(media);
      if (selected.provider.startsWith('server:') &&
          (fields['overview'] == null ||
              library.metadata.selectedArtwork(media) == null)) {
        if (!allowOnline) {
          queue.finish(media, owner, 'queued', phase: 1);
          return;
        }
        await service.refresh(media);
      }
      if (!allowOnline &&
          library.metadata
              .artworkCandidates(media)
              .any(
                (a) =>
                    a.remote != null ||
                    sources.configs
                            .where((c) => c.id == a.source?.instanceId)
                            .firstOrNull
                            ?.isFileSource ==
                        false,
              )) {
        queue.finish(media, owner, 'queued', phase: 1);
        return;
      }
      if (selected.provider == 'tmdb' &&
          (fields['overview'] == null ||
              library.metadata.selectedArtwork(media) == null)) {
        if (!allowOnline) {
          queue.finish(media, owner, 'queued', phase: 1);
          return;
        }
        if (!_configured) {
          queue.finish(
            media,
            owner,
            'waitingConfiguration',
            phase: 1,
            error: 'authRequired',
          );
          return;
        }
        await service.refresh(media);
      }
      await _images(media, owner);
      if (_valid(media, owner)) queue.finish(media, owner, 'completed');
      return;
    }
    if (!allowOnline) {
      queue.finish(media, owner, 'queued', phase: 1);
      return;
    }
    if (!_configured) {
      queue.finish(
        media,
        owner,
        'waitingConfiguration',
        phase: 1,
        error: 'authRequired',
      );
      return;
    }
    if (selected?.provider == 'tmdb') {
      await service.refresh(media);
      await _images(media, owner);
      if (_valid(media, owner)) {
        queue.finish(media, owner, 'completed', phase: 1);
      }
      return;
    }
    final evidence = service.evidence(media);
    final queryKind =
        [MediaKind.episode, MediaKind.season].contains(evidence.kind)
        ? MediaKind.series
        : evidence.kind;
    final job = await service.search(
      media,
      query: evidence.title,
      year: evidence.year,
      kind: queryKind,
    );
    if (!_valid(media, owner)) return;
    final jobInput = jsonDecode(library.metadata.job(job)['input'] as String);
    library.db.execute('UPDATE metadata_jobs SET input=? WHERE id=?', [
      jsonEncode({...jobInput, 'automaticMatchRule': matchRule}),
      job,
    ]);
    var match = uniqueMatch(
      evidence,
      _candidates(job),
      completePage: jobInput['nextPage'] == null,
    );
    if (match == null) {
      queue.finish(
        media,
        owner,
        _candidates(job).isEmpty ? 'unmatched' : 'awaitingSelection',
        phase: 1,
        job: job,
        error: _candidates(job).isEmpty ? 'noResults' : 'ambiguousMatch',
      );
      return;
    }
    if ([MediaKind.episode, MediaKind.season].contains(evidence.kind)) {
      await service.children(job, match.ref);
      if (!_valid(media, owner)) return;
      final season = _candidates(job)
          .where((c) => c.ref.season == evidence.season)
          .firstOrNull;
      if (season == null) {
        queue.finish(
          media,
          owner,
          'awaitingSelection',
          phase: 1,
          job: job,
          error: 'seasonUnclear',
        );
        return;
      }
      match = season;
      if (evidence.kind == MediaKind.episode) {
        await service.children(job, season.ref);
        if (!_valid(media, owner)) return;
        if (evidence.episodes.length != 1) {
          queue.finish(
            media,
            owner,
            'awaitingSelection',
            phase: 1,
            job: job,
            error: 'multipleEpisodes',
          );
          return;
        }
        match = _candidates(job)
            .where((c) => c.ref.episode == evidence.episodes.single)
            .firstOrNull;
        if (match == null) {
          queue.finish(
            media,
            owner,
            'unmatched',
            phase: 1,
            job: job,
            error: 'episodeMissing',
          );
          return;
        }
      }
    }
    await service.confirm(job, match.ref, userConfirmed: false);
    await _images(media, owner);
    if (_valid(media, owner)) {
      queue.finish(media, owner, 'completed', phase: 1, job: job);
    }
  }

  void stop() {
    _stopped = true;
    _service?.cancelActive();
    if (_owner != null && !library.isClosing) queue.release(_owner!);
  }

  Future<void> dispose() async {
    stop();
    artwork.dispose();
    await _service?.dispose();
  }
}
