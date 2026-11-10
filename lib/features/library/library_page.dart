import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../../l10n/generated/app_localizations.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../ui/components/states/content_state.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/media/content_row.dart';
import '../../ui/icons/app_icons.dart';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_manager.dart';
import '../../services/library/library_service.dart';
import '../../services/artwork/artwork_service.dart';
import 'media_detail_page.dart';
import 'metadata_artwork.dart';
import '../../ui/components/media/media_poster_card.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.sources,
    this.service,
    this.onPlay,
  });
  final SourceManager sources;
  final LibraryService? service;
  final ValueChanged<SourceSelection>? onPlay;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  AppLocalizations get l => AppLocalizations.of(context);
  LibraryService? _service;
  StreamSubscription<void>? _libraryChanges;
  late final ArtworkService _artwork = ArtworkService(
    widget.sources,
    retainedArtwork: () => _service?.metadata.retainedArtwork ?? [],
  );
  String _search = '';
  String? _error;
  // Scans run from the Sources page; the poster wall only reflects them.
  bool get _scanning =>
      _service?.fileSources().any((b) => b['status'] == '扫描中') ?? false;
  bool _resolving = false;
  int _offset = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  final _boostPending = <String>[];
  final _boosted = <String>{};
  bool _boostScheduled = false;

  /// Collects visible items and boosts them once per frame, so lazy list
  /// builders do not issue one write per row.
  void _boost(String media) {
    if (!_boosted.add(media)) return;
    _boostPending.add(media);
    if (_boostScheduled) return;
    _boostScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boostScheduled = false;
      final ids = List<String>.of(_boostPending);
      _boostPending.clear();
      if (mounted) _service?.prioritizeMetadata(ids);
    });
  }

  Future<void> _load() async {
    try {
      final service = widget.service ?? await LibraryService.open();
      await widget.sources.load();
      if (!mounted) {
        if (widget.service == null) service.close();
        return;
      }
      setState(() {
        _service = service;
        _libraryChanges = service.changes.listen((_) {
          if (mounted) setState(() {});
        });
      });
    } catch (_) {
      if (mounted) setState(() => _error = l.libraryLoadFailed);
    }
  }

  @override
  void dispose() {
    _libraryChanges?.cancel();
    _artwork.dispose();
    // Database closure waits for any active scan.
    if (widget.service == null) _service?.close();
    super.dispose();
  }

  Future<PlayableStream> _resolve(ResourceRef ref) async {
    if (ref.instanceId == '@local') {
      if (!await File(ref.id).exists()) throw StateError(l.localUnavailable);
      return PlayableStream(Uri.file(ref.id));
    }
    return widget.sources.resolve(ref);
  }

  String _resourceLabel(dynamic resource) {
    final checkpoint = _service!.checkpoint(resource['id'] as String);
    final progress = checkpoint != null && checkpoint['completed'] == 0
        ? l.watchedMinutes((checkpoint['position'] as int) ~/ 60000)
        : checkpoint?['completed'] == 1
        ? l.watchedSuffix
        : '';
    if (resource['source'] == '@local') return l.localResource(progress);
    final source = widget.sources.configs
        .where((c) => c.id == resource['source'] && c.enabled)
        .firstOrNull;
    if (source == null) return l.setupResource(progress);
    return '${source.displayName} · ${_service!.observedMissing(resource['id'] as String) ? l.missingOnScan : l.verifyOnPlay}$progress';
  }

  /// Movies and plain videos open the movie page, series the episode page.
  Future<void> _detail(dynamic media) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MediaDetailPage(
          service: _service!,
          sources: widget.sources,
          artwork: _artwork,
          media: media,
          play: _playResource,
          resourceLabel: _resourceLabel,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _playResource(BuildContext detail, dynamic resource) async {
    if (_resolving) return;
    _resolving = true;
    try {
      final ref = ResourceRef(
        resource['source'] as String,
        resource['item'] as String,
      );
      final stream = await _resolve(ref);
      if (!mounted || !detail.mounted) {
        await stream.release();
        return;
      }
      final selection = SourceSelection(
        resource['name'] as String,
        stream,
        ref: ref,
      );
      if (widget.onPlay != null) {
        widget.onPlay!(selection);
      } else {
        Navigator.pop(detail);
        Navigator.pop(context, selection);
      }
    } catch (_) {
      if (detail.mounted) {
        ShadToaster.of(
          detail,
        ).show(ShadToast.destructive(description: Text(l.versionOpenFailed)));
      }
    } finally {
      _resolving = false;
    }
  }

  Future<void> _openSearch() async {
    final controller = TextEditingController(text: _search);
    void apply(String value) => setState(() {
      _search = value;
      _offset = 0;
    });
    await showShadDialog<void>(
      context: context,
      builder: (c) => ShadDialog(
        title: Text(l.searchLibrary),
        actions: [
          if (_search.isNotEmpty)
            ShadButton.ghost(
              onPressed: () {
                controller.clear();
                apply('');
                Navigator.pop(c);
              },
              child: Text(l.cancel),
            ),
          ShadButton(onPressed: () => Navigator.pop(c), child: Text(l.close)),
        ],
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ShadInput(
            controller: controller,
            autofocus: true,
            placeholder: Text(l.searchLibrary),
            leading: Icon(AppIcons.search),
            onChanged: apply,
            onSubmitted: (_) => Navigator.pop(c),
          ),
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    final fileSources = service?.fileSources() ?? const <sql.Row>[];
    final rows = service == null
        ? []
        : service.query(null, search: _search, offset: _offset);
    final recent = service?.continueWatching() ?? const <sql.Row>[];
    // Recent/continue-watching entries are on screen: process them first.
    for (final media in recent) {
      _boost(media['id'] as String);
    }
    return PopScope(
      canPop: !_scanning,
      child: AppPage(
        actions: [
          if (service != null)
            Tooltip(
              message: l.searchLibrary,
              child: ShadIconButton.ghost(
                icon: Icon(
                  AppIcons.search,
                  // Tinted while a search is filtering the poster wall.
                  color: _search.isEmpty
                      ? null
                      : ShadTheme.of(context).colorScheme.primary,
                ),
                onPressed: _openSearch,
              ),
            ),
        ],
        body: service == null
            ? Center(
                child: _error == null
                    ? ContentState(message: l.loading, loading: true)
                    : Text(_error!),
              )
            : LayoutBuilder(
                builder: (context, layout) => Column(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: layout.maxHeight * 0.45,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            if (widget.onPlay == null && recent.isNotEmpty) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(l.continueIncludingHistory),
                                ),
                              ),
                              SizedBox(
                                height: 100,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    for (final media in recent)
                                      SizedBox(
                                        width: 240,
                                        child: ShadCard(
                                          padding: EdgeInsets.zero,
                                          child: ContentRow(
                                            leading: Icon(AppIcons.history),
                                            title: Text(
                                              media['title'] as String,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Text(
                                              l.watchProgress(
                                                (media['position'] as int) ~/
                                                    60000,
                                                (media['duration'] as int) ~/
                                                    60000,
                                              ),
                                            ),
                                            onTap: _scanning
                                                ? null
                                                : () => _detail(media),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            if (_scanning) ShadProgress(),
                            if (_error != null)
                              ShadAlert.destructive(title: Text(_error!)),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: fileSources.isEmpty && rows.isEmpty
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(l.libraryNoFileSources),
                              ),
                            )
                          : rows.isEmpty
                          ? Center(
                              child: Text(
                                _search.isNotEmpty
                                    ? l.noMatchingMedia
                                    : l.libraryEmptyNoMedia,
                              ),
                            )
                          : GridView.builder(
                              padding: EdgeInsets.all(16),
                              gridDelegate:
                                  SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 220,
                                    childAspectRatio: 0.5,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemCount: rows.length,
                              itemBuilder: (_, index) {
                                final media = rows[index];
                                _boost(media['id'] as String);
                                return MediaPosterCard(
                                  title: media['title'] as String,
                                  artwork:
                                      service.metadata.displayArtwork(
                                            media['id'] as String,
                                          ) ==
                                          null
                                      ? null
                                      : MetadataArtwork(
                                          service: _artwork,
                                          artwork: service.metadata
                                              .displayArtwork(
                                                media['id'] as String,
                                              )!,
                                        ),
                                  favorite: media['favorite'] == 1,
                                  onOpen: _scanning
                                      ? null
                                      : () => _detail(media),
                                  onFavorite: () => setState(
                                    () => service.favorite(
                                      media['id'] as String,
                                      media['favorite'] != 1,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ShadButton.ghost(
                          onPressed: _offset == 0
                              ? null
                              : () => setState(() => _offset -= 40),
                          enabled: !(_offset == 0),
                          child: Text(l.previousPage),
                        ),
                        Text('${_offset ~/ 40 + 1}'),
                        ShadButton.ghost(
                          onPressed: rows.length < 40
                              ? null
                              : () => setState(() => _offset += 40),
                          enabled: !(rows.length < 40),
                          child: Text(l.nextPage),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        title: Text(l.library),
      ),
    );
  }
}
