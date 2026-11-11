import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../services/metadata/tmdb_credentials.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/plugins/metadata_capability.dart';
import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_manager.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../plugins/metadata_tmdb/tmdb_metadata_plugin.dart';
import '../../services/artwork/artwork_service.dart';
import '../../services/library/library_service.dart';
import '../../services/metadata/metadata_service.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/media/tmdb_attribution.dart';
import '../../ui/components/media/content_row.dart';
import 'metadata_artwork.dart';

class MetadataPage extends StatefulWidget {
  const MetadataPage({
    super.key,
    required this.library,
    required this.sources,
    required this.media,
    this.service,
    this.credentials = tmdbCredentialStorage,
  });
  final LibraryService library;
  final SourceManager sources;
  final String media;
  final MetadataService? service;
  final FlutterSecureStorage credentials;
  @override
  State<MetadataPage> createState() => _MetadataPageState();
}

class _MetadataPageState extends State<MetadataPage> {
  AppLocalizations get l => AppLocalizations.of(context);
  StreamSubscription<void>? _libraryChanges;
  late MetadataService _service;
  late ArtworkService _artwork;
  final _query = TextEditingController(),
      _year = TextEditingController(),
      _providerId = TextEditingController();
  MediaKind _kind = MediaKind.movie;
  bool _busy = false, _configured = false;
  String? _error;
  String? _job;
  int _artworkLimit = 12;
  @override
  void initState() {
    super.initState();
    _service =
        widget.service ?? MetadataService(widget.library, widget.sources);
    _artwork = ArtworkService(
      widget.sources,
      retainedArtwork: () => widget.library.metadata.retainedArtwork,
    );
    final evidence = _service.evidence(widget.media);
    _query.text = evidence.title;
    _year.text = evidence.year?.toString() ?? '';
    _kind = evidence.kind == MediaKind.movie
        ? MediaKind.movie
        : MediaKind.series;
    _job = _service.repository.latestJob(widget.media)?['id'] as String?;
    _libraryChanges = widget.library.changes.listen((_) {
      if (mounted) {
        setState(() {
          if (!_busy) {
            _job =
                _service.repository.latestJob(widget.media)?['id'] as String?;
          }
        });
      }
    });
    if (widget.service == null) {
      _initialize();
    } else {
      _configured = true;
    }
  }

  Future<void> _initialize() async {
    try {
      final token = await widget.credentials.read(
        key: 'openplayx.metadata.tmdb.token',
      );
      if (!mounted) return;
      if (token?.isNotEmpty == true) {
        final transport = TmdbTransport(token!);
        _service.registry.register(
          'tmdb',
          TmdbMetadataPlugin(transport.get, onDispose: transport.close),
        );
        setState(() => _configured = true);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'authRequired');
    }
  }

  @override
  void dispose() {
    _libraryChanges?.cancel();
    _service.cancelActive();
    if (widget.service == null) _service.dispose();
    _artwork.dispose();
    _query.dispose();
    _year.dispose();
    _providerId.dispose();
    super.dispose();
  }

  String _message(String? code) => switch (code) {
    'authRequired' || 'unsupported' => l.metadataAuth,
    'networkUnavailable' || 'timeout' => l.metadataOffline,
    'permissionDenied' => l.metadataPermission,
    'rateLimited' => l.metadataRateLimited,
    'conflict' || 'cancelled' => l.metadataStale,
    'identityConflict' => l.metadataConflict,
    _ => l.metadataFailed,
  };
  String _status(String? stage) => switch (stage) {
    'completed' => l.metadataCompleted,
    'unmatched' => l.metadataUnmatched,
    'awaitingSelection' => l.metadataAwaiting,
    'failed' => l.metadataFailed,
    'cancelled' => l.metadataCancelled,
    'queued' ||
    'collecting' ||
    'fetching' ||
    'searching' ||
    'applying' => l.metadataBusy,
    _ => l.metadataNotStarted,
  };
  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PluginException
              ? error.code
              : 'invalidMetadata',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _job = _service.repository.latestJob(widget.media)?['id'] as String?;
        });
      }
    }
  }

  Future<void> _configure() async {
    var token = '';
    var language = _service.language;
    final saved = await showShadDialog<bool>(
      context: context,
      builder: (c) => ShadDialog(
        title: Text(l.metadataConfigure),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.pop(c),
            child: Text(l.cancel),
          ),
          ShadButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.save),
          ),
        ],
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.metadataPrivacy),
              const SizedBox(height: 16),
              ShadInput(
                obscureText: true,
                placeholder: Text(l.metadataToken),
                onChanged: (v) => token = v,
              ),
              const SizedBox(height: 12),
              ShadInput(
                initialValue: language,
                placeholder: Text(l.metadataLanguage),
                onChanged: (v) => language = v,
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;
    await _run(() async {
      if (!RegExp(r'^[a-z]{2,3}(?:-[A-Za-z]{2,4})?$').hasMatch(language)) {
        throw const PluginException('invalidInput', '语言无效');
      }
      if (token.trim().isNotEmpty) {
        await widget.credentials.write(
          key: 'openplayx.metadata.tmdb.token',
          value: token.trim(),
        );
      }
      if (!mounted) return;
      _service.repository.setSetting('language', language);
      if (token.trim().isNotEmpty) {
        _service.repository.setSetting(
          'tmdbRevision',
          '${DateTime.now().microsecondsSinceEpoch}',
        );
        await _service.dispose();
        if (!mounted) return;
        _service = MetadataService(widget.library, widget.sources);
        final transport = TmdbTransport(token.trim());
        _service.registry.register(
          'tmdb',
          TmdbMetadataPlugin(transport.get, onDispose: transport.close),
        );
        _configured = true;
      }
    });
  }

  Future<void> _confirm(MetadataRecord candidate, int index) async {
    final current = _service.repository.fields(widget.media);
    final yes = await showShadDialog<bool>(
      context: context,
      builder: (c) => ShadDialog(
        title: Text(l.metadataConfirm),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.pop(c),
            child: Text(l.cancel),
          ),
          ShadButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.metadataConfirm),
          ),
        ],
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${current['title'] ?? ''} → ${candidate.title}'),
                Text(
                  '${candidate.ref.provider} · ${candidate.ref.kind.name} · ${candidate.ref.id}',
                ),
                if (candidate.fields['year'] != null)
                  Text('${candidate.fields['year']}'),
                if (candidate.fields['overview'] != null)
                  Text(candidate.fields['overview'] as String),
                const SizedBox(height: 16),
                Text(l.metadataKeepLocks),
              ],
            ),
          ),
        ),
      ),
    );
    if (yes != true || !mounted) return;
    await _run(() async {
      if (candidate.ref.provider.startsWith('nfo:')) {
        await _service.chooseLocal(_job!, index);
      } else {
        await _service.confirm(_job!, candidate.ref);
      }
    });
  }

  Future<void> _edit(String field, String label) async {
    final repository = _service.repository;
    final revision = repository.revision(widget.media);
    var text = '${repository.fields(widget.media)[field] ?? ''}';
    final value = await showShadDialog<String>(
      context: context,
      builder: (c) => ShadDialog(
        title: Text(label),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.pop(c),
            child: Text(l.cancel),
          ),
          ShadButton(
            onPressed: () => Navigator.pop(c, text),
            child: Text(l.save),
          ),
        ],
        child: ShadInput(
          initialValue: text,
          maxLines: field == 'overview' ? 6 : 1,
          onChanged: (v) => text = v,
        ),
      ),
    );
    if (value == null || !mounted) return;
    await _run(() async {
      final dynamic parsed = field == 'year' ? int.tryParse(value) : value;
      if (field == 'year' && parsed == null) {
        throw const PluginException('invalidInput', '年份无效');
      }
      widget.library.transaction(
        () => repository.overrideField(
          widget.media,
          field,
          parsed,
          expectedRevision: revision,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = _service.repository;
    final fields = repo.fields(widget.media);
    final sources = repo.provenance(widget.media);
    final locks = repo.lockedFields(widget.media);
    final job = _job == null ? null : repo.job(_job!);
    final candidates = job?['stage'] == 'awaitingSelection'
        ? (jsonDecode(job!['candidates'] as String) as List)
              .map((e) => MetadataRecord.fromJson(e))
              .toList()
        : <MetadataRecord>[];
    final selected = repo.association(widget.media);
    final evidence = _service.evidence(widget.media);
    final target = evidence.kind;
    final poster = repo.selectedArtwork(widget.media);
    final backdrop = repo.selectedArtwork(widget.media, type: 'backdrop');
    final artworkCandidates = repo.artworkCandidates(widget.media);
    return AppPage(
      title: Text(l.metadata),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (backdrop != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: MetadataArtwork(
                        service: _artwork,
                        artwork: backdrop,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (poster != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: MetadataArtwork(
                          service: _artwork,
                          artwork: poster,
                          width: 110,
                          height: 165,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fields['title'] as String? ?? evidence.title,
                            style: ShadTheme.of(context).textTheme.h3,
                          ),
                          Text(
                            _status(
                              selected == null && job?['stage'] == 'completed'
                                  ? null
                                  : job?['stage'] as String? ??
                                        (selected != null ? 'completed' : null),
                            ),
                          ),
                          if (selected != null)
                            Text(
                              '${selected.provider} · ${selected.kind.name} · ${selected.id}',
                            ),
                          if (evidence.evidence.isNotEmpty)
                            Text(evidence.evidence.join(' · ')),
                          if (fields['overview'] is String)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                fields['overview'] as String,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_busy) const ShadProgress(),
                if (_busy)
                  ShadButton.ghost(
                    onPressed: _service.cancelActive,
                    child: Text(l.cancel),
                  ),
                if (_error != null || job?['error_code'] == 'identityConflict')
                  ShadAlert.destructive(
                    title: Text(_message(_error ?? 'identityConflict')),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ShadButton.outline(
                      enabled: !_busy,
                      onPressed: () =>
                          _run(() => _service.importSidecars(widget.media)),
                      child: Text(l.metadataImport),
                    ),
                    ShadButton.outline(
                      enabled: !_busy && selected != null,
                      onPressed: () =>
                          _run(() => _service.refresh(widget.media)),
                      child: Text(l.metadataRefresh),
                    ),
                    ShadButton.ghost(
                      enabled: !_busy,
                      onPressed: _configure,
                      child: Text(l.metadataConfigure),
                    ),
                    if (_configured)
                      ShadButton.ghost(
                        enabled: !_busy,
                        onPressed: () => _run(() async {
                          await widget.credentials.delete(
                            key: 'openplayx.metadata.tmdb.token',
                          );
                          if (!mounted) return;
                          _service.repository.setSetting(
                            'tmdbRevision',
                            '${DateTime.now().microsecondsSinceEpoch}',
                          );
                          await _service.dispose();
                          if (!mounted) return;
                          _service = MetadataService(
                            widget.library,
                            widget.sources,
                          );
                          _configured = false;
                        }),
                        child: Text(l.metadataForgetToken),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  l.metadataIdentify,
                  style: ShadTheme.of(context).textTheme.h4,
                ),
                Text(l.metadataPrivacy),
                const SizedBox(height: 12),
                ShadInput(
                  controller: _query,
                  placeholder: Text(l.metadataQuery),
                  enabled: !_busy,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 150,
                      child: ShadInput(
                        controller: _year,
                        placeholder: Text(l.metadataYear),
                        enabled: !_busy,
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: ShadInput(
                        controller: _providerId,
                        placeholder: Text(l.metadataProviderId),
                        enabled: !_busy,
                      ),
                    ),
                    ShadSelect<MediaKind>(
                      initialValue: _kind,
                      enabled: !_busy,
                      options: [
                        ShadOption(
                          value: MediaKind.movie,
                          child: Text(l.movie),
                        ),
                        ShadOption(
                          value: MediaKind.series,
                          child: Text(l.series),
                        ),
                      ],
                      selectedOptionBuilder: (_, v) =>
                          Text(v == MediaKind.movie ? l.movie : l.series),
                      onChanged: (v) {
                        if (v != null) setState(() => _kind = v);
                      },
                    ),
                    ShadButton(
                      enabled: !_busy && _configured,
                      onPressed: () => _run(() async {
                        if (_year.text.isNotEmpty &&
                            int.tryParse(_year.text) == null) {
                          throw const PluginException('invalidInput', '年份无效');
                        }
                        _job = await _service.search(
                          widget.media,
                          query: _query.text,
                          year: int.tryParse(_year.text),
                          kind: _kind,
                          providerId: _providerId.text.trim().isEmpty
                              ? null
                              : _providerId.text.trim(),
                        );
                      }),
                      child: Text(l.metadataSearch),
                    ),
                  ],
                ),
                if (candidates.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    l.metadataCandidates,
                    style: ShadTheme.of(context).textTheme.h4,
                  ),
                  for (var i = 0; i < candidates.length; i++)
                    ShadCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (candidates[i].artwork.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: MetadataArtwork(
                                service: _artwork,
                                artwork: candidates[i].artwork.first,
                                width: 90,
                                height: 135,
                              ),
                            ),
                          Text(
                            '${candidates[i].title} · ${candidates[i].fields['year'] ?? ''}',
                          ),
                          Text(
                            '${candidates[i].ref.provider} · ${candidates[i].ref.id} · ${candidates[i].ref.kind.name}',
                          ),
                          if (candidates[i].fields['overview'] != null)
                            Text(
                              candidates[i].fields['overview'] as String,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (candidates[i].ref.provider != 'tmdb' ||
                                  ![
                                    MediaKind.episode,
                                    MediaKind.season,
                                  ].contains(target) ||
                                  candidates[i].ref.kind == target)
                                ShadButton.outline(
                                  enabled: !_busy,
                                  onPressed: () => _confirm(candidates[i], i),
                                  child: Text(l.metadataConfirm),
                                ),
                              if (candidates[i].ref.provider == 'tmdb' &&
                                  [
                                    MediaKind.series,
                                    MediaKind.season,
                                  ].contains(candidates[i].ref.kind))
                                ShadButton.ghost(
                                  enabled: !_busy,
                                  onPressed: () => _run(
                                    () => _service.children(
                                      _job!,
                                      candidates[i].ref,
                                    ),
                                  ),
                                  child: Text(l.metadataChooseChildren),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ShadButton.ghost(
                    enabled: !_busy,
                    onPressed: () => setState(() => _service.cancel(_job!)),
                    child: Text(l.cancel),
                  ),
                ],
                const SizedBox(height: 24),
                Text(l.metadataEdit, style: ShadTheme.of(context).textTheme.h4),
                for (final entry in {
                  'title': l.correctTitle,
                  'originalTitle': l.metadataOriginalTitle,
                  'year': l.metadataYear,
                  'overview': l.metadataOverview,
                }.entries)
                  ContentRow(
                    title: Text(entry.value),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${fields[entry.key] ?? '—'}'),
                        Text(
                          '${sources[entry.key]?['source'] ?? 'filename'}${locks.contains(entry.key) ? ' 🔒' : ''}${sources[entry.key]?['missing'] == true ? ' · ${l.metadataMissingSource}' : ''}',
                        ),
                      ],
                    ),
                    onTap: _busy ? null : () => _edit(entry.key, entry.value),
                    trailing: locks.contains(entry.key)
                        ? ShadButton.ghost(
                            enabled: !_busy,
                            onPressed: () => _run(() async {
                              widget.library.transaction(
                                () => repo.overrideField(
                                  widget.media,
                                  entry.key,
                                  null,
                                  expectedRevision: repo.revision(widget.media),
                                ),
                              );
                            }),
                            child: Text(l.metadataRestore),
                          )
                        : null,
                  ),
                if (fields['genres'] is List)
                  Text((fields['genres'] as List).join(' · ')),
                if (fields['directors'] is List)
                  Text((fields['directors'] as List).join(' · ')),
                if (fields['cast'] is List)
                  Text(
                    (fields['cast'] as List)
                        .map((a) => '${a['name']} (${a['role'] ?? ''})')
                        .join(' · '),
                  ),
                if (fields['ratings'] is Map)
                  Text(
                    (fields['ratings'] as Map).entries
                        .map(
                          (e) =>
                              '${e.key}: ${e.value['value']}/${e.value['max']}',
                        )
                        .join(' · '),
                  ),
                const SizedBox(height: 24),
                Text(
                  l.metadataArtwork,
                  style: ShadTheme.of(context).textTheme.h4,
                ),
                if (repo.artworkLocked(widget.media))
                  Text(l.metadataArtworkLocked),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final artwork in artworkCandidates.take(_artworkLimit))
                      SizedBox(
                        width: artwork.type == 'poster' ? 150 : 240,
                        child: Column(
                          children: [
                            MetadataArtwork(
                              service: _artwork,
                              artwork: artwork,
                              width: artwork.type == 'poster' ? 150 : 240,
                              height: artwork.type == 'poster' ? 225 : 135,
                            ),
                            Text(
                              '${artwork.type} · ${artwork.language ?? 'und'}',
                            ),
                            ShadButton.outline(
                              enabled: !_busy,
                              onPressed: () => _run(() async {
                                widget.library.transaction(
                                  () => repo.selectArtwork(
                                    widget.media,
                                    artwork,
                                    expectedRevision: repo.revision(
                                      widget.media,
                                    ),
                                  ),
                                );
                              }),
                              child: Text(
                                repo
                                            .selectedArtwork(
                                              widget.media,
                                              type: artwork.type,
                                            )
                                            ?.id ==
                                        artwork.id
                                    ? l.metadataCompleted
                                    : l.metadataConfirm,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (artworkCandidates.length > _artworkLimit)
                  ShadButton.ghost(
                    onPressed: () => setState(() => _artworkLimit += 12),
                    child: Text(l.loadMore),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (['poster', 'backdrop', 'thumbnail'].any(
                      (type) => repo.artworkLocked(widget.media, type: type),
                    ))
                      ShadButton.ghost(
                        enabled: !_busy,
                        onPressed: () => _run(() async {
                          widget.library.transaction(() {
                            for (final type in [
                              'poster',
                              'backdrop',
                              'thumbnail',
                            ]) {
                              if (repo.artworkLocked(
                                widget.media,
                                type: type,
                              )) {
                                repo.unlockArtwork(
                                  widget.media,
                                  type: type,
                                  expectedRevision: repo.revision(widget.media),
                                );
                              }
                            }
                          });
                        }),
                        child: Text(l.metadataRestore),
                      ),
                    ShadButton.ghost(
                      enabled: !_busy,
                      onPressed: () => _run(_artwork.clear),
                      child: Text(l.metadataClearCache),
                    ),
                    ShadButton.ghost(
                      enabled: !_busy,
                      onPressed: () async {
                        final expectedRevision = repo.revision(widget.media);
                        final yes = await showShadDialog<bool>(
                          context: context,
                          builder: (c) => ShadDialog(
                            title: Text(l.metadataReset),
                            actions: [
                              ShadButton.ghost(
                                onPressed: () => Navigator.pop(c),
                                child: Text(l.cancel),
                              ),
                              ShadButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: Text(l.metadataReset),
                              ),
                            ],
                            child: Text(l.metadataResetDescription),
                          ),
                        );
                        if (yes == true && mounted) {
                          await _run(() async {
                            widget.library.transaction(
                              () => repo.reset(
                                widget.media,
                                expectedRevision: expectedRevision,
                                operationId:
                                    'reset:${DateTime.now().microsecondsSinceEpoch}',
                              ),
                            );
                          });
                        }
                      },
                      child: Text(l.metadataReset),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const TmdbAttribution(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
