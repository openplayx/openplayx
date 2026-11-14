import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/artwork/artwork_service.dart';
import '../../services/library/library_service.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/media/media_shelf.dart';
import 'metadata_artwork.dart';

/// Derives tile captions and badges from projected metadata.
abstract final class MediaTileInfo {
  static String? rating(Map<String, dynamic> fields) {
    final ratings = fields['ratings'];
    final tmdb = ratings is Map ? ratings['tmdb'] : null;
    final value = tmdb is Map ? tmdb['value'] : null;
    return value is num && value > 0 ? value.toStringAsFixed(1) : null;
  }

  static bool _series(LibraryService service, String id, Object? kind) {
    if (kind == 'series' || kind == 'season') return true;
    if (kind == 'movie' || kind == 'episode') return false;
    return service.children(id, limit: 1).isNotEmpty;
  }

  /// "共 N 季" for series, otherwise the release date (or year).
  static String? subtitle(
    BuildContext context,
    LibraryService service,
    String id,
    Map<String, dynamic> fields, {
    bool fullDate = false,
  }) {
    final l = AppLocalizations.of(context);
    final kind = fields['kind'];
    if (kind == 'episode') {
      final season = fields['season'], episode = fields['episode'];
      if (season is int && episode is int) {
        return l.seasonEpisodeShort(season, episode);
      }
    }
    if (_series(service, id, kind)) {
      final children = service.children(id, limit: 200);
      final seasons = children.where((c) => c['kind'] == 'season').length;
      if (seasons > 0) return l.seasonCount(seasons);
      if (children.isNotEmpty) return l.seasonCount(1);
    }
    final date = fields['airDate'];
    if (fullDate && date is String && date.length >= 10) {
      return date.substring(0, 10);
    }
    final year = fields['year'];
    if (year != null) return '$year';
    if (date is String && date.length >= 4) return date.substring(0, 4);
    return null;
  }

  static Widget? artwork(
    LibraryService service,
    ArtworkService artwork,
    String id, {
    bool landscape = false,
  }) {
    final metadata = service.metadata;
    final descriptor = landscape
        ? metadata.selectedArtwork(id, type: 'thumbnail') ??
              metadata.selectedArtwork(id, type: 'backdrop') ??
              metadata.selectedArtwork(id)
        : metadata.displayArtwork(id);
    return descriptor == null
        ? null
        : MetadataArtwork(service: artwork, artwork: descriptor);
  }

  static String clock(int ms) {
    final total = ms ~/ 1000;
    final h = total ~/ 3600, m = total % 3600 ~/ 60, s = total % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}

/// Poster tile bound to a library row.
class LibraryPosterTile extends StatelessWidget {
  const LibraryPosterTile({
    super.key,
    required this.service,
    required this.artwork,
    required this.media,
    this.onTap,
    this.fullDate = false,
  });
  final LibraryService service;
  final ArtworkService artwork;
  final dynamic media;
  final VoidCallback? onTap;
  final bool fullDate;

  @override
  Widget build(BuildContext context) {
    final id = media['id'] as String;
    final fields = service.metadata.fields(id);
    return PosterTile(
      title: (fields['title'] ?? media['title']).toString(),
      subtitle: MediaTileInfo.subtitle(
        context,
        service,
        id,
        fields,
        fullDate: fullDate,
      ),
      rating: MediaTileInfo.rating(fields),
      artwork: MediaTileInfo.artwork(service, artwork, id),
      onTap: onTap,
    );
  }
}

/// Continue-watching tile bound to a progress row.
class LibraryResumeTile extends StatelessWidget {
  const LibraryResumeTile({
    super.key,
    required this.service,
    required this.artwork,
    required this.row,
    this.onTap,
  });
  final LibraryService service;
  final ArtworkService artwork;
  final dynamic row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final id = row['id'] as String;
    final fields = service.metadata.fields(id);
    final position = row['position'] as int;
    final duration = row['duration'] as int;
    return LandscapeTile(
      title: (fields['title'] ?? row['title']).toString(),
      subtitle: MediaTileInfo.subtitle(context, service, id, fields),
      artwork: MediaTileInfo.artwork(service, artwork, id, landscape: true),
      timeLabel: duration > 0
          ? '${MediaTileInfo.clock(position)} / ${MediaTileInfo.clock(duration)}'
          : null,
      progress: duration > 0 ? position / duration : null,
      onTap: onTap,
    );
  }
}

/// Fills the width with equal columns no narrower than [minWidth].
class AdaptiveTileGrid extends StatelessWidget {
  const AdaptiveTileGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minWidth = ShelfMetrics.gridMinWidth,
    this.aspectRatio = 2 / 3,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double minWidth;

  /// Artwork width / height.
  final double aspectRatio;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      const gap = ShelfMetrics.gridGap;
      final width = constraints.crossAxisExtent;
      final columns = math.max(2, ((width + gap) / (minWidth + gap)).floor());
      final tile = (width - gap * (columns - 1)) / columns;
      return SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: gap,
          mainAxisSpacing: 18,
          mainAxisExtent:
              tile / aspectRatio + ShelfMetrics.captionHeight(context) + 4,
        ),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      );
    },
  );
}

/// "All" page behind a home shelf: an endless poster (or still) wall.
class LibraryGridPage extends StatefulWidget {
  const LibraryGridPage({
    super.key,
    required this.title,
    required this.service,
    required this.fetch,
    required this.tileBuilder,
    this.landscape = false,
  });
  final String title;
  final LibraryService service;
  final List<dynamic> Function(int offset, int limit) fetch;
  final Widget Function(BuildContext context, dynamic row) tileBuilder;
  final bool landscape;

  @override
  State<LibraryGridPage> createState() => _LibraryGridPageState();
}

class _LibraryGridPageState extends State<LibraryGridPage> {
  static const _page = 60;
  int _pages = 1;
  StreamSubscription<void>? _changes;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (var i = 0; i < _pages; i++) ...widget.fetch(i * _page, _page),
    ];
    final more = rows.length == _pages * _page;
    return AppPage(
      pageContext: const PageContextData(pageType: 'library_grid'),
      title: Text(widget.title),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (more && n.metrics.extentAfter < 600) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _pages * _page == rows.length) {
                setState(() => _pages++);
              }
            });
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              sliver: AdaptiveTileGrid(
                minWidth: widget.landscape ? 220 : ShelfMetrics.gridMinWidth,
                aspectRatio: widget.landscape ? 16 / 9 : 2 / 3,
                itemCount: rows.length,
                itemBuilder: (context, i) =>
                    widget.tileBuilder(context, rows[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
