import 'dart:convert';
import 'dart:math';

import 'tmdb_credentials.dart';

import '../../core/capabilities/metadata_capability.dart';
import '../../core/capabilities/source_capability.dart';
import '../../data/metadata/metadata_queue.dart';
import '../sources/source_manager.dart';
import 'providers/tmdb_metadata_plugin.dart';
import '../artwork/artwork_service.dart';
import '../library/library_service.dart';
import 'media_name_parser.dart';
import 'metadata_service.dart';
import '../../l10n/l10n.dart';

typedef MetadataCredentialReader = Future<String?> Function();

/// A bounded runner, usable by Android WorkManager and foreground desktop hosts.
/// It owns no widgets; fallback covers resolve videos through the artwork service.
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
       _usePlatform =
           credentials == null &&
           TmdbConfig.fromSettings(library.metadata.setting).usePlatform,
       _credentials =
           credentials ?? (() async => library.metadata.setting(tmdbTokenKey)),
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
  final bool _usePlatform;
  MetadataService? _service;
  bool _configured = false;
  bool _stopped = false;
  String? _owner;
  String? _activeMedia;
  static const matchRule = 'original-title-alias-year-v4';

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
    final members = [
      for (final r in library.db.select(
        'SELECT media_id FROM memberships ORDER BY media_id',
      ))
        r['media_id'] as String,
    ];
    // The legacy TMDB language setting (no longer editable) stays in the key
    // so existing keys stay valid. The UI language is deliberately not part
    // of it: switching language must not scrape everything again.
    final language = library.metadata.setting('language');
    final tmdbRevision = library.metadata.setting('tmdbRevision');
    for (final media in members) {
      inputs[media] = MetadataQueue.fingerprint([
        resourcesByMedia[media] ?? const <List<Object?>>[],
        language,
        tmdbRevision,
      ]);
    }
    final added = queue.reconcile(inputs);
    // A new name rule can match items the previous one could not: give every
    // automatic miss one more try (user-confirmed matches are untouched).
    final rule =
        '${MediaNameEvidence.ruleVersion}/$matchRule/cover-one-fifth-v2';
    if (library.metadata.setting('nameRule') != rule) {
      library.db.execute(
        '''UPDATE metadata_queue SET state='queued',phase=0,attempts=0,next_at=0,error_code=NULL,
        job_id=NULL,lease_owner=NULL,lease_until=NULL
        WHERE state IN ('unmatched','awaitingSelection','failed')
          AND NOT EXISTS (SELECT 1 FROM metadata_state s WHERE s.media_id=metadata_queue.media_id AND s.association IS NOT NULL)''',
      );
      library.metadata.setSetting('nameRule', rule);
      return added + library.db.updatedRows;
    }
    return added;
  }

  Future<MetadataService> _metadata({required bool allowOnline}) async {
    if (_service != null) {
      if (allowOnline && !_configured) {
        String? token;
        try {
          token = await _credentials();
        } catch (_) {}
        if (_usePlatform || token?.trim().isNotEmpty == true) {
          final transport = _usePlatform
              ? TmdbTransport.platform()
              : TmdbTransport(token!.trim());
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
      if (_usePlatform || token?.trim().isNotEmpty == true) {
        final transport = _usePlatform
            ? TmdbTransport.platform()
            : TmdbTransport(token!.trim());
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
                : PluginException(
                    'metadataFailed',
                    appStrings.errBackgroundIdentify,
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

  Future<void> _fallbackCover(
    String media,
    String owner, {
    String? pendingJob,
  }) async {
    final metadata = library.metadata;
    if (metadata.displayArtwork(media) != null ||
        metadata.association(media) != null) {
      return;
    }
    final resource = library.resources(media).firstOrNull;
    if (resource == null) return;
    final revision = metadata.revision(media);
    final image = ArtworkDescriptor(
      id: '${ArtworkService.videoCoverPrefix}${resource['id']}',
      type: 'poster',
      source: ResourceRef(
        resource['source'] as String,
        resource['item'] as String,
      ),
    );
    try {
      await artwork.load(image);
    } catch (_) {
      // A missing decoder or unreadable video does not change a catalog miss.
      return;
    }
    if (!_valid(media, owner) || metadata.revision(media) != revision) return;
    library.transaction(() {
      final applied = metadata.apply(
        media,
        MetadataRecord(
          ref: MetadataRef('video-cover', MediaKind.movie, media),
          fields: const {},
          artwork: [image],
        ),
        sourceKey: 'video-cover',
        authority: 0,
        expectedRevision: revision,
        operationId: 'video-cover:$media:$revision',
      );
      if (applied && pendingJob != null) {
        // Artwork alone does not invalidate the candidates we just fetched.
        // Rebase only this job from the exact revision used for our cover;
        // concurrent user edits must still make a candidate job stale.
        library.db.execute(
          'UPDATE metadata_jobs SET revision=? WHERE id=? AND revision=?',
          [metadata.revision(media), pendingJob, revision],
        );
      }
    });
  }

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
      library.metadata.language,
    );
    if (logos.isNotEmpty && _valid(media, owner)) {
      await artwork.resolveLogo(logos);
    }
  }

  List<MetadataRecord> _candidates(String job) =>
      (jsonDecode(library.metadata.job(job)['candidates'] as String) as List)
          .map((e) => MetadataRecord.fromJson(e as Map<String, dynamic>))
          .toList();
  static String _name(String title) => title.toLowerCase().replaceAll(
    RegExp(r"[\s._\-\[\](){}:：·,!！?？、，。'’‘]"),
    '',
  );

  /// The normalized names a file title may go by in the catalog. Release
  /// names often carry a marketing suffix the catalog title lacks ("F1 The
  /// Movie" is TMDB's "F1"), so the name with it dropped counts too.
  static Set<String> _wanted(MediaNameEvidence evidence) {
    final wanted = _name(evidence.title);
    if (wanted.isEmpty) return const {};
    final suffix = RegExp(r'(the)?movie$').firstMatch(wanted);
    return {
      wanted,
      if (suffix != null && suffix.start > 0) wanted.substring(0, suffix.start),
    };
  }

  static bool _sameYear(MediaNameEvidence evidence, MetadataRecord c) =>
      evidence.year == null || c.fields['year'] == evidence.year;

  static MetadataRecord? uniqueMatch(
    MediaNameEvidence evidence,
    List<MetadataRecord> candidates, {
    bool completePage = true,
  }) {
    final names = _wanted(evidence);
    if (!completePage || names.isEmpty) return null;
    // Translated display titles can collide even when the original titles
    // identify different works. Prefer the file's exact original-title match
    // so switching the UI language cannot introduce that ambiguity.
    final originals = candidates
        .where(
          (c) =>
              names.contains(
                _name(c.fields['originalTitle'] as String? ?? ''),
              ) &&
              _sameYear(evidence, c),
        )
        .toList();
    if (originals.isNotEmpty) {
      return originals.length == 1 ? originals.single : dominant(originals);
    }
    final matches = candidates
        .where(
          (c) =>
              [
                _name(c.title),
                _name(c.fields['originalTitle'] as String? ?? ''),
              ].any(names.contains) &&
              _sameYear(evidence, c),
        )
        .toList();
    return matches.length == 1 ? matches.single : dominant(matches);
  }

  /// How far the most popular of several equally matching candidates must
  /// lead the next one before it is taken automatically.
  static double popularityLead = 10;

  static double _popularity(MetadataRecord c) =>
      (c.fields['popularity'] as num?)?.toDouble() ?? 0;
  static int _votes(MetadataRecord c) =>
      (((c.fields['ratings'] as Map?)?['tmdb'] as Map?)?['votes'] as num?)
          ?.toInt() ??
      0;

  /// Same title and year, several catalog entries: TMDB often lists obscure
  /// same-name titles beside a well-known one ("The Odyssey" 2026). Take the
  /// one whose popularity leads every other by [popularityLead] times and
  /// whose vote count no other candidate exceeds; otherwise ask the user.
  static MetadataRecord? dominant(List<MetadataRecord> tied) {
    if (tied.length < 2) return tied.singleOrNull;
    final ranked = [...tied]
      ..sort((a, b) => _popularity(b).compareTo(_popularity(a)));
    final top = ranked.first;
    final lead = _popularity(top);
    if (lead < 1 || lead < popularityLead * _popularity(ranked[1])) return null;
    if (tied.any((c) => !identical(c, top) && _votes(c) > _votes(top))) {
      return null;
    }
    return top;
  }

  static String _episodeName(String title) => _name(
    title.replaceAll(
      RegExp(
        r'\((?:\d|part\s*\d)\)|\b(?:part|pt)\.?\s*\d\b',
        caseSensitive: false,
      ),
      '',
    ),
  ).replaceAll('&', 'and');

  static double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    final shorter = a.length < b.length ? a : b;
    if (shorter.length >= 8 && (a.contains(b) || b.contains(a))) return 0.9;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = [i, ...List.filled(b.length, 0)];
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = min(
          min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }
      previous = current;
    }
    return 1 - previous[b.length] / max(a.length, b.length);
  }

  /// The catalog episode a file titled [title] is, when its release number
  /// [number] points at an episode with a clearly different title and exactly
  /// one other episode of the season clearly carries that title (two-parters merged
  /// in the catalog shift later numbers). Null keeps the number. [names] are
  /// each episode's titles (display language, plus English); a merged
  /// two-parter's "Part A; Part B" title matches either part.
  static int? episodeByTitle(
    String title,
    int number,
    Map<int, List<String>> names,
  ) {
    final wanted = _episodeName(title);
    if (wanted.length < 3) return null;
    double score(int episode) {
      var best = 0.0;
      for (final name in names[episode] ?? const <String>[]) {
        for (final part in [name, ...name.split(';')]) {
          best = max(best, _similarity(wanted, _episodeName(part)));
        }
      }
      return best;
    }

    // Titles of one show share openings ("The One With", "And the"), so a
    // number is only overruled by an episode that matches clearly (>= 0.8),
    // clearly better than the numbered one (+0.15), and alone at the top.
    final here = names.containsKey(number) ? score(number) : 0.0;
    final scores = {for (final e in names.keys) e: score(e)};
    final top = scores.values.fold(0.0, max);
    final better = [
      for (final MapEntry(key: e, value: v) in scores.entries)
        if (e != number && v >= 0.8 && v >= here + 0.15 && v >= top - 0.05) e,
    ];
    return better.length == 1 ? better.single : null;
  }

  static MediaNameEvidence _withoutYear(MediaNameEvidence e) =>
      MediaNameEvidence(
        original: e.original,
        title: e.title,
        kind: e.kind,
        season: e.season,
        episodes: e.episodes,
        tags: e.tags,
        evidence: e.evidence,
        extra: e.extra,
        episodeTitle: e.episodeTitle,
      );

  /// Whether any candidate carries the file's title, whatever its year.
  static bool hasTitleMatch(
    MediaNameEvidence evidence,
    List<MetadataRecord> candidates,
  ) {
    final names = _wanted(evidence);
    return candidates.any(
      (c) => [
        _name(c.title),
        _name(c.fields['originalTitle'] as String? ?? ''),
      ].any(names.contains),
    );
  }

  /// At most this many same-year candidates have their alternative titles
  /// fetched; with more, uniqueness could not be shown and nothing is fetched.
  static const aliasCandidates = 3;

  /// Fallback when no catalog title equals the file title: the file title
  /// must equal an alternative title of exactly one same-year candidate.
  /// Needs a year from the file and a complete result page.
  static Future<MetadataRecord?> aliasMatch(
    MediaNameEvidence evidence,
    List<MetadataRecord> candidates,
    Future<List<String>> Function(MetadataRef ref) alternativeTitles, {
    bool completePage = true,
  }) async {
    final names = _wanted(evidence);
    if (!completePage || names.isEmpty || evidence.year == null) return null;
    final sameYear = candidates.where((c) => _sameYear(evidence, c)).toList();
    if (sameYear.isEmpty || sameYear.length > aliasCandidates) return null;
    final matches = <MetadataRecord>[];
    for (final c in sameYear) {
      final titles = await alternativeTitles(c.ref);
      if (titles.map(_name).any(names.contains)) matches.add(c);
    }
    return matches.length == 1 ? matches.single : null;
  }

  /// The exact-title match, else the alternative-title one, for a search job.
  Future<MetadataRecord?> _match(
    String job,
    MediaNameEvidence evidence,
    MetadataService service, {
    int? nearYear,
  }) async {
    final input = jsonDecode(library.metadata.job(job)['input'] as String);
    final complete = input['nextPage'] == null;
    var candidates = _candidates(job);
    if (nearYear != null) {
      // Year-less retry: only titles released within a year of the file's.
      candidates = [
        for (final c in candidates)
          if (c.fields['year'] is int &&
              ((c.fields['year'] as int) - nearYear).abs() <= 1)
            c,
      ];
      evidence = _withoutYear(evidence);
    }
    final match =
        uniqueMatch(evidence, candidates, completePage: complete) ??
        await aliasMatch(
          evidence,
          candidates,
          service.alternativeTitles,
          completePage: complete,
        );
    if (match != null || !complete || candidates.isEmpty) return match;
    // Release names carry English titles; in another UI language the
    // candidates show translated titles and an original in the source
    // language ("Castle in the Sky" vs 天空之城 / 天空の城ラピュタ). Compare
    // with the same search's English titles before giving up.
    if (service.language.startsWith('en') ||
        !RegExp(r'[A-Za-z]{2}').hasMatch(evidence.title)) {
      return null;
    }
    final english = await service.searchTitles(
      input['query'] as String,
      kind: MediaKind.values.byName(input['kind'] as String),
      year: input['year'] as int?,
    );
    final byKey = {for (final c in candidates) c.ref.key: c};
    final translated = [
      for (final r in english.records)
        if (byKey.containsKey(r.ref.key)) r,
    ];
    final found = uniqueMatch(
      evidence,
      translated,
      completePage: english.nextPage == null,
    );
    return found == null ? null : byKey[found.ref.key];
  }

  Future<void> _process(
    String media,
    String owner,
    int phase, {
    required bool allowOnline,
  }) async {
    final member = library.db.select(
      'SELECT 1 FROM memberships WHERE media_id=?',
      [media],
    );
    final resources = library.resources(media);
    if (member.isEmpty) return;
    if (resources.isNotEmpty &&
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
      await service.importSidecars(media, skipUnreadable: true);
      if (!_valid(media, owner)) return;
      final local = library.metadata.latestJob(media);
      if (local?['stage'] == 'awaitingSelection' &&
          (jsonDecode(local!['input'] as String) as Map).containsKey(
            'sidecars',
          )) {
        queue.finish(
          media,
          owner,
          'awaitingSelection',
          error: local['error_code'] as String?,
          job: local['id'] as String?,
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
    final evidence = service.evidence(media);
    if (selected == null && evidence.extra) {
      await _extra(media, owner, service, evidence, allowOnline: allowOnline);
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
    final queryKind =
        [MediaKind.episode, MediaKind.season].contains(evidence.kind)
        ? MediaKind.series
        : evidence.kind;
    var job = await service.search(
      media,
      query: evidence.title,
      year: evidence.year,
      kind: queryKind,
    );
    if (!_valid(media, owner)) return;
    final jobInput = jsonDecode(
      library.metadata.job(job)['input'] as String,
    ) as Map<String, dynamic>;
    library.db.execute('UPDATE metadata_jobs SET input=? WHERE id=?', [
      jsonEncode({...jobInput, 'automaticMatchRule': matchRule}),
      job,
    ]);
    var match = await _match(job, evidence, service);
    if (!_valid(media, owner)) return;
    // Release names can carry a year the catalog does not (festival vs.
    // release year, "God of Gamblers II 1991" for TMDB's 1990). When no
    // candidate of that year even has the title, search again without the
    // year and accept a unique title within one year of the file's.
    if (match == null &&
        evidence.year != null &&
        !hasTitleMatch(evidence, _candidates(job))) {
      final retry = await service.search(
        media,
        query: evidence.title,
        kind: queryKind,
      );
      if (!_valid(media, owner)) return;
      final retryInput = jsonDecode(
        library.metadata.job(retry)['input'] as String,
      ) as Map<String, dynamic>;
      library.db.execute('UPDATE metadata_jobs SET input=? WHERE id=?', [
        jsonEncode({
          ...retryInput,
          'automaticMatchRule': matchRule,
          'yearRetry': evidence.year,
        }),
        retry,
      ]);
      match = await _match(retry, evidence, service, nearYear: evidence.year);
      if (!_valid(media, owner)) return;
      if (match != null || _candidates(retry).isNotEmpty) {
        job = retry;
        jobInput
          ..clear()
          ..addAll(retryInput);
      }
    }
    if (match == null) {
      final noResults =
          _candidates(job).isEmpty && jobInput['nextPage'] == null;
      // An ambiguous catalog title still needs a local video cover. Keep
      // candidates and awaitingSelection while supplying the artwork.
      await _fallbackCover(media, owner, pendingJob: job);
      if (!_valid(media, owner)) return;
      queue.finish(
        media,
        owner,
        noResults ? 'unmatched' : 'awaitingSelection',
        phase: 1,
        job: job,
        error: noResults ? 'noResults' : 'ambiguousMatch',
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
        final episodes = _candidates(job);
        var number = evidence.episodes.single;
        final title = evidence.episodeTitle;
        if (title != null && episodes.isNotEmpty) {
          final names = <int, List<String>>{
            for (final c in episodes)
              if (c.ref.episode != null) c.ref.episode!: [c.title],
          };
          if (!service.language.startsWith('en')) {
            final english = await service.episodeTitles(season.ref);
            if (!_valid(media, owner)) return;
            english.forEach((e, t) => (names[e] ??= []).add(t));
          }
          number = episodeByTitle(title, number, names) ?? number;
        }
        match = episodes.where((c) => c.ref.episode == number).firstOrNull;
        if (match == null) {
          await _fallbackCover(media, owner);
          if (!_valid(media, owner)) return;
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

  /// Bonus clips are never matched as titles of their own: they are filed
  /// under the movie or series in their folder, or under the TMDB series
  /// their name points to. Until then they stay out of matching.
  Future<void> _extra(
    String media,
    String owner,
    MetadataService service,
    MediaNameEvidence evidence, {
    required bool allowOnline,
  }) async {
    final host = service.extraHost(media);
    if (host != null) {
      service.attachExtra(media, host);
      queue.finish(media, owner, 'skipped', phase: 1, error: 'extra');
      return;
    }
    if (allowOnline && _configured) {
      final job = await service.search(
        media,
        query: evidence.title,
        year: evidence.year,
        kind: MediaKind.series,
      );
      if (!_valid(media, owner)) return;
      final match = await _match(job, evidence, service);
      if (!_valid(media, owner)) return;
      if (match != null) {
        await service.attachExtraToSeries(job, match.ref);
        if (_valid(media, owner)) {
          queue.finish(media, owner, 'skipped', phase: 1, error: 'extra');
        }
        return;
      }
    }
    if (!allowOnline) {
      queue.finish(media, owner, 'queued', phase: 1);
      return;
    }
    // The movie or episodes beside it may be identified later.
    if (service.extraHostPending(media)) {
      queue.finish(
        media,
        owner,
        'queued',
        phase: 1,
        delay: const Duration(minutes: 2),
        retryable: true,
      );
      return;
    }
    queue.finish(media, owner, 'unmatched', phase: 1, error: 'extraNoHost');
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
