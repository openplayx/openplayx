import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/plugins/metadata_capability.dart';
import '../../core/plugins/source_capability.dart';
import '../../data/sources/source_config.dart';
import '../../data/sources/source_manager.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/artwork/artwork_service.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/media/media_poster_card.dart';
import '../../ui/components/media/source_kind_icon.dart';
import '../../ui/components/states/content_state.dart';
import '../../ui/icons/app_icons.dart';
import 'metadata_artwork.dart';

/// Opens a server entry: folders browse deeper, files play.
typedef ServerEntryHandler = void Function(
  BuildContext context,
  SourceEntry entry,
);

/// Poster for a server entry, using the server's own artwork when it has one.
class ServerPosterTile extends StatelessWidget {
  const ServerPosterTile({
    super.key,
    required this.entry,
    required this.artwork,
    required this.onOpen,
  });
  final SourceEntry entry;
  final ArtworkService artwork;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final media = entry.media;
    final theme = ShadTheme.of(context);
    final Widget? poster =
        media != null && media.artworkTypes.contains('poster')
        ? MetadataArtwork(
            service: artwork,
            artwork: ArtworkDescriptor(
              id: 'server:${entry.ref.instanceId}:poster:${media.id}',
              type: 'poster',
              source: ResourceRef(
                entry.ref.instanceId,
                'artwork:poster:${media.id}',
              ),
            ),
          )
        : entry.isFolder
        ? Center(
            child: Icon(
              AppIcons.folder,
              size: 48,
              color: theme.colorScheme.mutedForeground,
            ),
          )
        : null;
    return MediaPosterCard(
      title: entry.name,
      artwork: poster,
      favorite: false,
      onFavorite: () {},
      onOpen: onOpen,
    );
  }
}

/// One media server in the library: a header and a row of its newest items.
class ServerShelf extends StatefulWidget {
  const ServerShelf({
    super.key,
    required this.sources,
    required this.config,
    required this.artwork,
    required this.onOpen,
  });
  final SourceManager sources;
  final SourceConfig config;
  final ArtworkService artwork;
  final ServerEntryHandler onOpen;
  static const tileWidth = 140.0;

  @override
  State<ServerShelf> createState() => _ServerShelfState();
}

class _ServerShelfState extends State<ServerShelf> {
  AppLocalizations get l => AppLocalizations.of(context);
  late Future<List<SourceEntry>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.sources.featured(widget.config.id);
  }

  void _retry() =>
      setState(() => _items = widget.sources.featured(widget.config.id));

  void _browseAll() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ServerBrowsePage(
        sources: widget.sources,
        artwork: widget.artwork,
        instanceId: widget.config.id,
        title: widget.config.titleName,
        onOpen: widget.onOpen,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              SourceKindIcon(widget.config.kind, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.config.titleName,
                  style: theme.textTheme.large,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ShadButton.ghost(
                onPressed: _browseAll,
                trailing: Icon(AppIcons.next),
                child: Text(l.serverBrowseAll),
              ),
            ],
          ),
        ),
        SizedBox(
          height: ServerShelf.tileWidth * 1.5 + 48 * textScale,
          child: FutureBuilder<List<SourceEntry>>(
            future: _items,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ContentState(
                  message: snapshot.error is PluginException
                      ? (snapshot.error as PluginException).message
                      : l.serverUnavailable,
                  error: true,
                  onRetry: _retry,
                );
              }
              if (!snapshot.hasData) {
                return ContentState(message: l.loading, loading: true);
              }
              final items = snapshot.data!;
              if (items.isEmpty) return ContentState(message: l.serverEmpty);
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => SizedBox(
                  width: ServerShelf.tileWidth,
                  child: ServerPosterTile(
                    entry: items[index],
                    artwork: widget.artwork,
                    onOpen: () => widget.onOpen(context, items[index]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Poster wall of one server folder (or the server's libraries at the root),
/// loading further pages as it scrolls.
class ServerBrowsePage extends StatefulWidget {
  const ServerBrowsePage({
    super.key,
    required this.sources,
    required this.artwork,
    required this.instanceId,
    required this.title,
    required this.onOpen,
    this.node,
  });
  final SourceManager sources;
  final ArtworkService artwork;
  final String instanceId;
  final String title;
  final ResourceRef? node;
  final ServerEntryHandler onOpen;

  @override
  State<ServerBrowsePage> createState() => _ServerBrowsePageState();
}

class _ServerBrowsePageState extends State<ServerBrowsePage> {
  AppLocalizations get l => AppLocalizations.of(context);
  final _entries = <SourceEntry>[];
  int? _next = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> _more() async {
    final offset = _next;
    if (_loading || offset == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.sources.browse(
        widget.instanceId,
        BrowseRequest(node: widget.node, offset: offset, limit: 60),
      );
      if (!mounted) return;
      setState(() {
        _entries.addAll(page.entries);
        _next = page.nextOffset;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PluginException
              ? error.message
              : l.serverUnavailable,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    body: _entries.isEmpty
        ? Center(
            child: _error != null
                ? ContentState(message: _error!, error: true, onRetry: _more)
                : _loading
                ? ContentState(message: l.loading, loading: true)
                : ContentState(message: l.serverEmpty),
          )
        : NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 400) _more();
              return false;
            },
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          childAspectRatio: 0.55,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) => ServerPosterTile(
                      entry: _entries[index],
                      artwork: widget.artwork,
                      onOpen: () => widget.onOpen(context, _entries[index]),
                    ),
                  ),
                ),
                if (_loading || _error != null || _next != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: _error != null
                          ? ContentState(
                              message: _error!,
                              error: true,
                              onRetry: _more,
                            )
                          : Center(
                              child: ShadButton.ghost(
                                onPressed: _loading ? null : _more,
                                child: Text(
                                  _loading ? l.loading : l.serverLoadMore,
                                ),
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
  );
}
