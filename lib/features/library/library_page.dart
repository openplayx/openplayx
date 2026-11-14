import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../../l10n/generated/app_localizations.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

import '../../ui/components/states/content_state.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/media/content_row.dart';
import '../../ui/icons/app_icons.dart';

import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_config.dart';
import '../../data/sources/source_manager.dart';
import '../../services/library/library_service.dart';
import '../../services/artwork/artwork_service.dart';
import 'media_opener.dart';
import 'media_tiles.dart';
import 'server_shelf.dart';
import '../../ui/components/feedback/app_feedback.dart';

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

class _LibraryPageState extends State<LibraryPage>
    with MediaOpener<LibraryPage> {
  static const _page = 60;
  int _pages = 1;

  @override
  SourceManager get openerSources => widget.sources;
  @override
  LibraryService? get openerService => _service;
  @override
  ArtworkService get openerArtwork => _artwork;
  @override
  ValueChanged<SourceSelection>? get openerPlay => widget.onPlay;

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

  Future<void> _detail(dynamic media) => openDetail(media);

  /// Server shelf / browse tap: folders open their poster wall, files play.
  Future<void> _openEntry(BuildContext from, SourceEntry entry) async {
    if (entry.isFolder) {
      await Navigator.of(from).push<void>(
        MaterialPageRoute(
          builder: (_) => ServerBrowsePage(
            sources: widget.sources,
            artwork: _artwork,
            instanceId: entry.ref.instanceId,
            title: entry.name,
            node: entry.ref,
            onOpen: _openEntry,
          ),
        ),
      );
      return;
    }
    if (_resolving) return;
    _resolving = true;
    try {
      final stream = await widget.sources.resolve(entry.ref);
      if (!mounted) {
        await stream.release();
        return;
      }
      final selection = SourceSelection(
        entry.name,
        stream,
        ref: entry.ref,
        entry: entry,
      );
      if (widget.onPlay != null) {
        widget.onPlay!(selection);
      } else {
        final own = ModalRoute.of(context);
        Navigator.of(context).popUntil((route) => route == own);
        Navigator.pop(context, selection);
      }
    } catch (error) {
      if (from.mounted) {
        showAppToast(
          from,
          error is PluginException ? error.message : l.versionOpenFailed,
          kind: FeedbackKind.error,
        );
      }
    } finally {
      _resolving = false;
    }
  }

  Future<void> _openSearch() async {
    final controller = TextEditingController(text: _search);
    void apply(String value) => setState(() {
      _search = value;
      _pages = 1;
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
    final fileSources =
        service?.fileSources() ?? const <Map<String, Object?>>[];
    final rows = service == null
        ? []
        : [
            for (var i = 0; i < _pages; i++)
              ...service.query(
                search: _search,
                offset: i * _page,
                limit: _page,
              ),
          ];
    final more = rows.length == _pages * _page;
    final recent = service?.continueWatching() ?? const <sql.Row>[];
    // A search filters the local wall only, so the shelves step aside.
    final servers = service == null || _search.isNotEmpty
        ? const <SourceConfig>[]
        : widget.sources.configs
              .where((c) => c.enabled && !c.isFileSource)
              .toList();
    // Recent/continue-watching entries are on screen: process them first.
    for (final media in recent) {
      _boost(media['id'] as String);
    }
    return PopScope(
      canPop: !_scanning,
      child: AppPage(
        pageContext: const PageContextData(pageType: 'library'),
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
            : NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (more && n.metrics.extentAfter < 600) {
                    final loaded = rows.length;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _pages * _page == loaded) {
                        setState(() => _pages++);
                      }
                    });
                  }
                  return false;
                },
                child: CustomScrollView(
                  slivers: [
                    if (widget.onPlay == null && recent.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(l.continueIncludingHistory),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
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
                                          (media['position'] as int) ~/ 60000,
                                          (media['duration'] as int) ~/ 60000,
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
                      ),
                    ],
                    if (_scanning) SliverToBoxAdapter(child: ShadProgress()),
                    if (_error != null)
                      SliverToBoxAdapter(child: AppAlert.error(title: _error!)),
                    // Media servers keep their own catalogues and artwork, so
                    // each gets a shelf instead of being merged into the wall.
                    for (final server in servers)
                      SliverToBoxAdapter(
                        child: ServerShelf(
                          key: ValueKey(
                            'shelf-${server.id}-${server.revision}',
                          ),
                          sources: widget.sources,
                          config: server,
                          artwork: _artwork,
                          onOpen: _openEntry,
                        ),
                      ),
                    if (servers.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                          child: Text(
                            l.localLibrary,
                            style: ShadTheme.of(context).textTheme.large,
                          ),
                        ),
                      ),
                    if (rows.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: servers.isEmpty ? 120 : 32,
                          ),
                          child: Center(
                            child: Text(
                              fileSources.isEmpty
                                  ? l.libraryNoFileSources
                                  : _search.isNotEmpty
                                  ? l.noMatchingMedia
                                  : l.libraryEmptyNoMedia,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                          20,
                          MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                          32,
                        ),
                        sliver: AdaptiveTileGrid(
                          itemCount: rows.length,
                          itemBuilder: (_, index) {
                            final media = rows[index];
                            _boost(media['id'] as String);
                            return LibraryPosterTile(
                              service: service,
                              artwork: _artwork,
                              media: media,
                              fullDate: true,
                              onTap: _scanning ? null : () => _detail(media),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
        title: Text(l.library),
      ),
    );
  }
}
