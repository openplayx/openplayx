import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../data/library/scan_status.dart';

import '../../../capabilities/sources/source_manager.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../capabilities/artwork/artwork_service.dart';
import '../../../capabilities/library/file_source.dart';
import '../../../capabilities/library/library_service.dart';
import '../../../ui/components/media/media_shelf.dart';
import '../../../ui/icons/app_icons.dart';
import '../controller/home_controller.dart';
import 'media_opener.dart';
import '../model/home_shelves.dart';
import 'media_tiles.dart';
import 'metadata_artwork.dart';
import '../../../ui/adaptive/app_experience.dart';
import '../../../ui/tv/tv_action.dart';

part 'home_tv.dart';

/// Home: VidHub-style shelves — continue watching, recently added, movies
/// and TV shows — each with an "All · N" entry into a full poster wall.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.sources,
    required this.service,
    required this.onPlay,
    required this.onResume,
    this.onAddVideo,
    this.revealRevision = 0,
  });
  final VoidCallback? onAddVideo;
  final int revealRevision;
  final SourceManager sources;
  final LibraryService service;
  final ValueChanged<SourceSelection> onPlay;

  /// Continues the exact recorded resource of a progress row.
  final ValueChanged<dynamic> onResume;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with MediaOpener<HomePage> {
  late final ArtworkService _artwork = ArtworkService(
    widget.sources,
    retainedArtwork: () => widget.service.metadata.retainedArtwork,
  );
  @override
  SourceManager get openerSources => widget.sources;
  @override
  LibraryService? get openerService => widget.service;
  @override
  ArtworkService get openerArtwork => _artwork;
  @override
  ValueChanged<SourceSelection>? get openerPlay => widget.onPlay;

  late final HomeController _controller = HomeController(widget.service)
    ..addListener(_changed);
  HomeShelves get _shelves => _controller.shelves;
  ValueListenable<TickerModeData>? _visible;
  final _scroll = ScrollController();

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.getValuesNotifier(context);
    if (!identical(visible, _visible)) {
      _visible?.removeListener(_onVisibility);
      _visible = visible..addListener(_onVisibility);
      _onVisibility();
    }
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The shell recreates the page when the home tab is selected again.
    _controller.reload();
    if (widget.revealRevision != oldWidget.revealRevision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
  }

  void _onVisibility() =>
      _controller.setVisible(_visible?.value.enabled ?? true);

  @override
  void dispose() {
    _visible?.removeListener(_onVisibility);
    _controller.dispose();
    _scroll.dispose();
    _artwork.dispose();
    super.dispose();
  }

  void _openAll(
    String title,
    List<dynamic> Function(int offset, int limit) fetch, {
    bool landscape = false,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: const RouteSettings(name: 'LibraryGridPage'),
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
            contentType: contentType,
            offset: offset,
            limit: limit,
          ),
        ),
        padding: _padding,
        tileWidth: _television ? 164 : ShelfMetrics.posterWidth,
        tileHeight: (_television ? 164 : ShelfMetrics.posterWidth) * 1.5,
        itemCount: rows.length,
        itemBuilder: (_, i) => LibraryPosterTile(
          key: ValueKey(rows[i]['id']),
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
    final shown = rows.take(HomeController.shelfLimit).toList();
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
        tileWidth: _television ? 280 : ShelfMetrics.landscapeWidth,
        tileHeight: (_television ? 280 : ShelfMetrics.landscapeWidth) * 9 / 16,
        itemCount: shown.length,
        itemBuilder: (_, i) => LibraryResumeTile(
          key: ValueKey(shown[i]['resource_id'] ?? shown[i]['id']),
          autofocus: _television && i == 0,
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

  bool get _television => AppExperience.isTelevision(context);

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
    ];
    final empty = shelves.every((s) => s is SizedBox);
    // Scan progress only fills an otherwise empty home; once videos show up the
    // shelves themselves are the progress. Failures and empty results stay visible.
    final statuses = _controller.scanStates.map((state) {
      final f = state.source;
      final count = state.count;
      final retry =
          f.status == ScanStatus.failed || f.status == ScanStatus.interrupted;
      if (f.scanning && !empty ||
          !f.scanning &&
              !retry &&
              !(f.status == ScanStatus.done && count == 0)) {
        return const SizedBox.shrink();
      }
      // Once videos show, a failed source is one quiet row instead of a card
      // pushing the shelves down; tapping it reveals the full reason.
      if (retry && !empty) return _failedScanRow(l, f);
      return Padding(
        padding: _padding.add(const EdgeInsets.only(bottom: 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.name ?? l.sourceRootFolder),
            Text(
              f.scanning
                  ? l.homeFindingVideos(count)
                  : retry
                  ? l.homeScanInterrupted
                  : l.homeNoVideos,
            ),
            if (retry && f.error != null) Text(ScanStatus.error(f.error)!),
            if (retry)
              ShadButton.ghost(
                onPressed: () => service.startScan(f.id, widget.sources),
                child: Text(l.retry),
              ),
            if (!f.scanning && widget.onAddVideo != null)
              ShadButton.ghost(
                onPressed: widget.onAddVideo,
                child: Text(l.homeAdjustScope),
              ),
          ],
        ),
      );
    }).toList();
    if (empty && statuses.every((s) => s is SizedBox)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                !_controller.hasFileSources
                    ? l.libraryNoFileSources
                    : l.libraryEmptyNoMedia,
                textAlign: TextAlign.center,
              ),
              if (widget.onAddVideo != null) ...[
                const SizedBox(height: 16),
                if (_television)
                  TvAction(
                    key: const ValueKey('tv-home-add-video'),
                    autofocus: true,
                    onPressed: widget.onAddVideo,
                    child: Text(
                      l.addVideo,
                      style: const TextStyle(fontSize: 22),
                    ),
                  )
                else
                  ShadButton(
                    key: const ValueKey('home-add-video-empty'),
                    onPressed: widget.onAddVideo,
                    child: Text(l.addVideo),
                  ),
              ],
            ],
          ),
        ),
      );
    }
    return ListView(
      key: const PageStorageKey('home'),
      controller: _scroll,
      // Keep the last shelf reachable above the floating bar while allowing
      // earlier shelves to scroll behind its backdrop filter.
      padding: EdgeInsets.only(
        top: 20,
        bottom: 12 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (_television && _shelves.recentlyAdded.isNotEmpty)
          _tvHero(_shelves.recentlyAdded.first),
        ...statuses,
        ...shelves,
      ],
    );
  }

  final _expandedScanErrors = <Object>{};

  Widget _failedScanRow(AppLocalizations l, FileSource f) {
    final theme = ShadTheme.of(context);
    final reason = ScanStatus.error(f.error);
    final expanded = _expandedScanErrors.contains(f.id);
    final status = f.status == ScanStatus.failed
        ? l.scanStatusFailed
        : l.scanStatusInterrupted;
    return Padding(
      key: ValueKey('home-scan-failed-${f.id}'),
      padding: _padding.add(const EdgeInsets.only(bottom: 12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              AppIcons.warning,
              size: 16,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: reason == null
                  ? null
                  : () => setState(() {
                      if (!_expandedScanErrors.remove(f.id)) {
                        _expandedScanErrors.add(f.id);
                      }
                    }),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${f.name ?? l.sourceRootFolder} · $status',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.small,
                  ),
                  if (reason != null)
                    Text(
                      reason,
                      maxLines: expanded ? null : 1,
                      overflow: expanded ? null : TextOverflow.ellipsis,
                      style: theme.textTheme.muted.copyWith(fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: () => widget.service.startScan(f.id, widget.sources),
            child: Text(l.retry),
          ),
        ],
      ),
    );
  }
}
