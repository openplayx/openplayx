import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_theme_controller.dart';
import '../../data/sources/source_manager.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/artwork/artwork_service.dart';
import '../../services/library/library_service.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/media/content_row.dart';
import '../../ui/icons/app_icons.dart';
import '../../ui/tokens/app_spacing.dart';
import 'metadata_artwork.dart';
import 'metadata_page.dart';

/// Plays one resource of a media item; supplied by the library page.
typedef PlayResource = Future<void> Function(
  BuildContext context,
  dynamic resource,
);

/// Opens a library item: a series gets the season/episode page, everything
/// else (movies, episodes, plain videos) gets the movie page.
class MediaDetailPage extends StatefulWidget {
  const MediaDetailPage({
    super.key,
    required this.service,
    required this.sources,
    required this.artwork,
    required this.media,
    required this.play,
    required this.resourceLabel,
  });
  final LibraryService service;
  final SourceManager sources;
  final ArtworkService artwork;
  final dynamic media;
  final PlayResource play;
  final String Function(dynamic resource) resourceLabel;

  static bool isSeries(LibraryService service, String id) {
    final kind = service.metadata.fields(id)['kind'];
    if (kind == 'series' || kind == 'season') return true;
    if (kind == 'movie' || kind == 'episode') return false;
    return service.children(id, limit: 1).isNotEmpty;
  }

  @override
  State<MediaDetailPage> createState() => _MediaDetailPageState();
}

class _MediaDetailPageState extends State<MediaDetailPage> {
  AppLocalizations get l => AppLocalizations.of(context);
  LibraryService get service => widget.service;
  String get _id => widget.media['id'] as String;
  bool _busy = false;
  String? _seasonId;

  Map<String, dynamic> get _fields => service.metadata.fields(_id);
  late final bool _series = MediaDetailPage.isSeries(service, _id);

  @override
  void initState() {
    super.initState();
    // Opening a detail page makes this item (and its episodes) top priority.
    service.prioritizeMetadata([
      _id,
      ...service.children(_id, limit: 50).map((c) => c['id'] as String),
    ]);
  }

  Future<void> _play(dynamic resource) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.play(context, resource);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Plays a media item, asking which version when it has several.
  Future<void> _playMedia(String media) async {
    final resources = service.resources(media);
    if (resources.isEmpty) return;
    if (resources.length == 1) return _play(resources.first);
    final picked = await showShadDialog<dynamic>(
      context: context,
      builder: (c) => ShadDialog(
        title: Text(l.chooseVersion),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 360),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final resource in resources)
                ContentRow(
                  leading: Icon(AppIcons.playMedia),
                  title: Text(resource['name'] as String),
                  subtitle: Text(widget.resourceLabel(resource)),
                  onTap: () => Navigator.pop(c, resource),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) await _play(picked);
  }

  Future<void> _openMetadata() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            MetadataPage(library: service, sources: widget.sources, media: _id),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final fields = _fields;
    final title = (fields['title'] ?? widget.media['title']).toString();
    final poster = service.metadata.displayArtwork(_id);
    return AppPage(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        // Raw metadata editing is a debugging tool, hidden unless enabled.
        if (AppAppearance.maybeOf(context)?.developerMode ?? false)
          Tooltip(
            message: l.metadata,
            child: ShadIconButton.ghost(
              key: const ValueKey('media-metadata'),
              icon: Icon(AppIcons.info),
              onPressed: _openMetadata,
            ),
          ),
      ],
      body: ListView(
        padding: AppSpacing.page(context),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, box) {
                      final wide = box.maxWidth >= 640;
                      final cover = ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: wide ? 220 : 160,
                          child: AspectRatio(
                            aspectRatio: 2 / 3,
                            child: ColoredBox(
                              color: theme.colorScheme.muted,
                              child: poster == null
                                  ? Center(
                                      child: Icon(AppIcons.movie, size: 48),
                                    )
                                  : MetadataArtwork(
                                      service: widget.artwork,
                                      artwork: poster,
                                    ),
                            ),
                          ),
                        ),
                      );
                      final info = _info(title, fields);
                      return wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                cover,
                                const SizedBox(width: AppSpacing.xl),
                                Expanded(child: info),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                cover,
                                const SizedBox(height: AppSpacing.lg),
                                info,
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (_series) ..._episodes() else ..._versions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String title, Map<String, dynamic> fields) {
    final theme = ShadTheme.of(context);
    final ratings = fields['ratings'];
    final tmdb = ratings is Map ? ratings['tmdb'] : null;
    final score = tmdb is Map && tmdb['value'] is num
        ? (tmdb['value'] as num).toStringAsFixed(1)
        : null;
    final genres = (fields['genres'] as List?)?.join(' / ');
    final facts = [
      if (fields['year'] != null) '${fields['year']}',
      if (score != null) '★ $score',
      if (genres != null && genres.isNotEmpty) genres,
    ].join('  ·  ');
    final original = fields['originalTitle']?.toString();
    final directors = (fields['directors'] as List?)?.join(', ');
    final cast = [
      for (final c in (fields['cast'] as List? ?? []).take(8))
        if (c is Map && c['name'] != null) c['name'],
    ].join(', ');
    final overview = fields['overview']?.toString();
    final firstResource = service.resources(_id).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.h2),
        if (original != null && original.isNotEmpty && original != title)
          Text(original, style: theme.textTheme.muted),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(facts, style: theme.textTheme.muted),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (!_series && firstResource != null)
          ShadButton(
            enabled: !_busy,
            leading: Icon(AppIcons.play, size: 18),
            onPressed: () => _playMedia(_id),
            child: Text(l.play),
          ),
        if (overview != null && overview.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(l.detailOverview, style: theme.textTheme.large),
          const SizedBox(height: AppSpacing.xs),
          Text(overview),
        ],
        if (directors != null && directors.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            '${l.detailDirectors}: $directors',
            style: theme.textTheme.muted,
          ),
        ],
        if (cast.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text('${l.detailCast}: $cast', style: theme.textTheme.muted),
        ],
      ],
    );
  }

  /// Movie page: the resource versions, only worth listing when there are
  /// several to choose from.
  List<Widget> _versions() {
    final resources = service.resources(_id);
    if (resources.length < 2) return const [];
    return [
      Text(l.chooseVersion, style: ShadTheme.of(context).textTheme.large),
      const SizedBox(height: AppSpacing.sm),
      for (final resource in resources)
        ContentRow(
          leading: Icon(AppIcons.playMedia),
          title: Text(resource['name'] as String),
          subtitle: Text(widget.resourceLabel(resource)),
          onTap: _busy ? null : () => _play(resource),
        ),
    ];
  }

  int _number(dynamic value) => value is int ? value : 0;

  /// Series page: season picker (when the series has seasons) and episodes.
  List<Widget> _episodes() {
    final theme = ShadTheme.of(context);
    final children = service.children(_id, limit: 500);
    final seasons = [
      for (final c in children)
        if (c['kind'] == 'season') c,
    ]..sort((a, b) => _number(a['season']).compareTo(_number(b['season'])));
    final dynamic season = seasons.isEmpty
        ? null
        : seasons.firstWhere(
            (s) => s['id'] == _seasonId,
            orElse: () => seasons.first,
          );
    final episodes = [
      ...(season == null
          ? children
          : service.children(season['id'] as String, limit: 500)),
    ]..sort((a, b) => _number(a['episode']).compareTo(_number(b['episode'])));
    return [
      if (seasons.length > 1) ...[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final s in seasons)
              (s['id'] == season['id']
                  ? ShadButton.secondary
                  : ShadButton.outline)(
                onPressed: () => setState(() => _seasonId = s['id'] as String),
                child: Text(l.seasonLabel(_number(s['season']))),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (episodes.isEmpty)
        Text(l.detailNoEpisodes, style: theme.textTheme.muted)
      else
        for (final episode in episodes) _episodeRow(episode),
    ];
  }

  Widget _episodeRow(dynamic episode) {
    final id = episode['id'] as String;
    final number = _number(episode['episode']);
    final still = service.metadata.displayArtwork(id);
    final playable = service.resources(id).isNotEmpty;
    return ContentRow(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 112,
          height: 63,
          child: ColoredBox(
            color: ShadTheme.of(context).colorScheme.muted,
            child: still == null
                ? Center(child: Icon(AppIcons.playMedia))
                : MetadataArtwork(
                    service: widget.artwork,
                    artwork: still,
                    width: 112,
                    height: 63,
                  ),
          ),
        ),
      ),
      title: Text(
        number > 0
            ? '${l.episodeLabel(number)}  ${episode['title']}'
            : '${episode['title']}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        (service.metadata.fields(id)['overview'] ?? '').toString(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: _busy || !playable ? null : () => _playMedia(id),
    );
  }
}
