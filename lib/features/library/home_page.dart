import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/sources/source_manager.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/artwork/artwork_service.dart';
import '../../services/library/library_service.dart';
import '../../ui/components/media/media_shelf.dart';
import 'media_opener.dart';
import 'media_tiles.dart';

/// Home: VidHub-style shelves — continue watching, recently added, movies
/// and TV shows — each with an "All · N" entry into a full poster wall.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.sources,
    required this.service,
    required this.onPlay,
    required this.onResume,
  });
  final SourceManager sources;
  final LibraryService service;
  final ValueChanged<SourceSelection> onPlay;

  /// Continues the exact recorded resource of a progress row.
  final ValueChanged<dynamic> onResume;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with MediaOpener<HomePage> {
  static const _shelfLimit = 20;
  late final ArtworkService _artwork = ArtworkService(
    widget.sources,
    retainedArtwork: () => widget.service.metadata.retainedArtwork,
  );
  StreamSubscription<void>? _changes;
  final _boosted = <String>{};
  final _boostPending = <String>[];

  /// Queues on-screen items for metadata once, flushed after the frame.
  void _boost(String id) {
    if (!_boosted.add(id)) return;
    if (_boostPending.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ids = List<String>.of(_boostPending);
        _boostPending.clear();
        if (mounted) widget.service.prioritizeMetadata(ids);
      });
    }
    _boostPending.add(id);
  }

  @override
  SourceManager get openerSources => widget.sources;
  @override
  LibraryService? get openerService => widget.service;
  @override
  ArtworkService get openerArtwork => _artwork;
  @override
  ValueChanged<SourceSelection>? get openerPlay => widget.onPlay;

  /// Shelf rows, queried outside build: the queries are synchronous and cost
  /// tens of milliseconds, and build also runs on resize and theme changes.
  late _HomeShelves _shelves;

  /// Library changed while this page was hidden (another tab, a pushed
  /// route); reloaded once it becomes visible again.
  bool _stale = false;
  ValueListenable<TickerModeData>? _visible;

  @override
  void initState() {
    super.initState();
    _shelves = _load();
    _changes = widget.service.changes.listen((_) => _refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.getValuesNotifier(context);
    if (!identical(visible, _visible)) {
      _visible?.removeListener(_onVisibility);
      _visible = visible..addListener(_onVisibility);
    }
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The shell recreates the page when the home tab is selected again.
    _shelves = _load();
    _stale = false;
  }

  void _onVisibility() {
    if (_stale && (_visible?.value.enabled ?? true)) _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    if (!(_visible?.value.enabled ?? true)) {
      _stale = true;
      return;
    }
    _stale = false;
    setState(() => _shelves = _load());
  }

  _HomeShelves _load() {
    final service = widget.service;
    List<dynamic> posters(String? contentType) =>
        service.query(null, contentType: contentType, limit: _shelfLimit);
    final shelves = _HomeShelves(
      continueWatching: service.continueWatching(limit: 200),
      recentlyAdded: posters(null),
      movies: posters('movie'),
      series: posters('series'),
      recentlyPlayed: service.recentlyPlayed(limit: 200),
    );
    for (final rows in [
      shelves.recentlyAdded,
      shelves.movies,
      shelves.series,
    ]) {
      for (final row in rows) {
        _boost(row['id'] as String);
      }
    }
    return shelves;
  }

  @override
  void dispose() {
    _visible?.removeListener(_onVisibility);
    _changes?.cancel();
    _artwork.dispose();
    super.dispose();
  }

  void _openAll(
    String title,
    List<dynamic> Function(int offset, int limit) fetch, {
    bool landscape = false,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => LibraryGridPage(
        title: title,
        service: widget.service,
        fetch: fetch,
        landscape: landscape,
        tileBuilder: (context, row) => landscape
            ? LibraryResumeTile(
                service: widget.service,
                artwork: _artwork,
                row: row,
                onTap: () => widget.onResume(row),
              )
            : LibraryPosterTile(
                service: widget.service,
                artwork: _artwork,
                media: row,
                fullDate: true,
                onTap: () => openDetail(row, from: context),
              ),
      ),
    ),
  );

  Widget _posterShelf(String title, String? contentType, List<dynamic> rows) {
    final service = widget.service;
    if (rows.isEmpty) return const SizedBox.shrink();
    final total = rows.first['total'] as int? ?? rows.length;
    return _section(
      MediaShelf(
        title: title,
        trailing: AppLocalizations.of(context).shelfViewAll(total),
        onViewAll: () => _openAll(
          title,
          (offset, limit) => service.query(
            null,
            contentType: contentType,
            offset: offset,
            limit: limit,
          ),
        ),
        padding: _padding,
        tileWidth: ShelfMetrics.posterWidth,
        tileHeight: ShelfMetrics.posterWidth * 1.5,
        itemCount: rows.length,
        itemBuilder: (_, i) => LibraryPosterTile(
          service: service,
          artwork: _artwork,
          media: rows[i],
          onTap: () => openDetail(rows[i]),
        ),
      ),
    );
  }

  Widget _resumeShelf(
    String title,
    List<dynamic> rows,
    List<dynamic> Function(int) load,
  ) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final shown = rows.take(_shelfLimit).toList();
    return _section(
      MediaShelf(
        title: title,
        trailing: AppLocalizations.of(context).shelfViewAll(rows.length),
        onViewAll: () => _openAll(
          title,
          (offset, limit) => offset > 0 ? const [] : load(200),
          landscape: true,
        ),
        padding: _padding,
        tileWidth: ShelfMetrics.landscapeWidth,
        tileHeight: ShelfMetrics.landscapeWidth * 9 / 16,
        itemCount: shown.length,
        itemBuilder: (_, i) => LibraryResumeTile(
          service: widget.service,
          artwork: _artwork,
          row: shown[i],
          onTap: () => widget.onResume(shown[i]),
        ),
      ),
    );
  }

  EdgeInsets get _padding => EdgeInsets.symmetric(
    horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 30,
  );

  Widget _section(Widget child) =>
      Padding(padding: const EdgeInsets.only(bottom: 28), child: child);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final service = widget.service;
    final shelves = [
      _resumeShelf(
        l.continueWatching,
        _shelves.continueWatching,
        (limit) => service.continueWatching(limit: limit),
      ),
      _posterShelf(l.recentlyAdded, null, _shelves.recentlyAdded),
      _posterShelf(l.movie, 'movie', _shelves.movies),
      _posterShelf(l.tvShows, 'series', _shelves.series),
      _resumeShelf(
        l.recentlyPlayed,
        _shelves.recentlyPlayed,
        (limit) => service.recentlyPlayed(limit: limit),
      ),
    ];
    final empty = shelves.every((s) => s is SizedBox);
    if (empty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            service.fileSources().isEmpty
                ? l.libraryNoFileSources
                : l.libraryEmptyNoMedia,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      key: const PageStorageKey('home'),
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      children: shelves,
    );
  }
}

class _HomeShelves {
  const _HomeShelves({
    required this.continueWatching,
    required this.recentlyAdded,
    required this.movies,
    required this.series,
    required this.recentlyPlayed,
  });
  final List<dynamic> continueWatching;
  final List<dynamic> recentlyAdded;
  final List<dynamic> movies;
  final List<dynamic> series;
  final List<dynamic> recentlyPlayed;
}
