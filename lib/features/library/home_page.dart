import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    _changes = widget.service.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
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

  Widget _posterShelf(String title, String? contentType) {
    final service = widget.service;
    final rows = service.query(
      null,
      contentType: contentType,
      limit: _shelfLimit,
    );
    if (rows.isEmpty) return const SizedBox.shrink();
    final total = rows.first['total'] as int? ?? rows.length;
    for (final row in rows) {
      _boost(row['id'] as String);
    }
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

  Widget _resumeShelf(String title, List<dynamic> Function(int) load) {
    final rows = load(200);
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
        (limit) => service.continueWatching(limit: limit),
      ),
      _posterShelf(l.recentlyAdded, null),
      _posterShelf(l.movie, 'movie'),
      _posterShelf(l.tvShows, 'series'),
      _resumeShelf(
        l.recentlyPlayed,
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
