import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_theme_controller.dart';
import '../../core/plugins/metadata_capability.dart';
import '../../data/sources/source_manager.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/artwork/artwork_service.dart';
import '../../services/library/library_service.dart';
import '../../ui/adaptive/app_page.dart';
import '../../ui/components/media/content_row.dart';
import '../../ui/icons/app_icons.dart';
import '../../ui/tokens/app_spacing.dart';
import 'country_names.dart';
import 'metadata_artwork.dart';
import 'metadata_page.dart';
import 'title_logo.dart';

/// Plays one resource of a media item; supplied by the library page.
typedef PlayResource = Future<void> Function(
  BuildContext context,
  dynamic resource,
);

/// Cinematic detail page: a full-bleed backdrop that melts into a blurred
/// wash of its own colours, the title (logo when available) above a glass
/// play button, facts and overview beside it, then horizontal shelves for
/// episodes, the film collection, cast and crew, versions and genres.
///
/// The page always draws light-on-dark over its artwork, whatever the app
/// theme, so the backdrop colours carry the look.
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

/// Fixed palette of the detail page (drawn over artwork in both themes).
abstract final class _C {
  static const base = Color(0xFF121214);
  static const text = Color(0xFFFFFFFF);
  static const body = Color(0xEBFFFFFF);
  static const secondary = Color(0xD9FFFFFF);
  static const muted = Color(0x8CFFFFFF);
  static const divider = Color(0x80FFFFFF);
  static const glass = Color(0x38FFFFFF);
  static const glassHover = Color(0x4DFFFFFF);
  static const chip = Color(0x1FFFFFFF);
  static const chipHover = Color(0x33FFFFFF);
  static const tile = Color(0x14FFFFFF);
  static const star = Color(0xFFFFB800);
}

/// Measurements taken from the reference design (logical pixels).
abstract final class _M {
  static const gutter = 24.0;
  static const columnInset = 6.0;
  static const columnWidth = 200.0;
  static const columnGap = 30.0;
  static const rightPadding = 40.0;
  static const buttonHeight = 35.0;
  static const buttonGap = 11.0;
  static const sectionGap = 36.0;
  static const headerGap = 16.0;
  static const posterWidth = 110.0;
  static const posterGap = 16.0;
  static const avatar = 80.0;
  static const avatarGap = 12.0;
  static const stillWidth = 210.0;
  static const stillGap = 23.0;
  static const cardRadius = 10.0;
  static const episodeChunk = 10;
}

const _sectionTitle = TextStyle(
  color: _C.text,
  fontSize: 15,
  fontWeight: FontWeight.w600,
  height: 1.3,
);

class _MediaDetailPageState extends State<MediaDetailPage> {
  AppLocalizations get l => AppLocalizations.of(context);
  LibraryService get service => widget.service;
  String get _id => widget.media['id'] as String;
  bool _busy = false;
  String? _seasonId;
  StreamSubscription<void>? _changes;
  final _episodeScroll = ScrollController();
  int _episodeChunk = 0;

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
    // Background scraping publishes titles, artwork and episodes while open.
    _changes = service.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _episodeScroll.addListener(_trackEpisodeChunk);
  }

  @override
  void dispose() {
    _changes?.cancel();
    _episodeScroll.dispose();
    super.dispose();
  }

  void _trackEpisodeChunk() {
    final stride = _M.stillWidth + _M.stillGap;
    final chunk = (_episodeScroll.offset / stride + 0.5) ~/ _M.episodeChunk;
    if (chunk != _episodeChunk) setState(() => _episodeChunk = chunk);
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
    final picked = await _chooseVersion(media);
    if (picked != null && mounted) await _play(picked);
  }

  Future<dynamic> _chooseVersion(String media) => showShadDialog<dynamic>(
    context: context,
    builder: (c) => ShadDialog(
      title: Text(l.chooseVersion),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 360),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final resource in service.resources(media))
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

  Future<void> _pickVersionAndPlay() async {
    final picked = await _chooseVersion(_id);
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

  void _openMedia(dynamic media) {
    if (media['id'] == _id) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MediaDetailPage(
          service: service,
          sources: widget.sources,
          artwork: widget.artwork,
          media: media,
          play: widget.play,
          resourceLabel: widget.resourceLabel,
        ),
      ),
    );
  }

  int _number(dynamic value) => value is int ? value : 0;

  List<dynamic> get _seasons => [
    for (final c in service.children(_id, limit: 500))
      if (c['kind'] == 'season') c,
  ]..sort((a, b) => _number(a['season']).compareTo(_number(b['season'])));

  dynamic _season(List<dynamic> seasons) => seasons.isEmpty
      ? null
      : seasons.firstWhere(
          (s) => s['id'] == _seasonId,
          orElse: () => seasons.first,
        );

  List<dynamic> _episodesOf(dynamic season) => [
    ...(season == null
        ? service.children(_id, limit: 500)
        : service.children(season['id'] as String, limit: 500)),
  ]..sort((a, b) => _number(a['episode']).compareTo(_number(b['episode'])));

  /// The episode the play button starts: one in progress, else the first
  /// unfinished, else the first.
  String? _nextEpisode() {
    final seasons = _seasons;
    final episodes = [
      for (final season in seasons.isEmpty ? [null] : seasons)
        ..._episodesOf(season),
    ].where((e) => service.resources(e['id'] as String).isNotEmpty).toList();
    if (episodes.isEmpty) return null;
    Map<String, dynamic>? state(dynamic e) {
      final r = service.resources(e['id'] as String).first;
      return service.checkpoint(r['id'] as String);
    }

    for (final e in episodes) {
      final s = state(e);
      if (s != null && s['completed'] == 0 && (s['position'] ?? 0) > 0) {
        return e['id'] as String;
      }
    }
    for (final e in episodes) {
      if (state(e)?['completed'] != 1) return e['id'] as String;
    }
    return episodes.first['id'] as String;
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fields;
    final title = (fields['title'] ?? widget.media['title']).toString();
    final backdrop =
        service.metadata.selectedArtwork(_id, type: 'backdrop') ??
        service.metadata.selectedArtwork(_id, type: 'thumbnail');
    final poster = service.metadata.selectedArtwork(_id);
    final wash = backdrop ?? poster;
    final developer = AppAppearance.maybeOf(context)?.developerMode ?? false;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: _C.base,
      body: DefaultTextStyle.merge(
        style: TextStyle(
          color: _C.text,
          fontFamily: ShadTheme.of(context).textTheme.p.fontFamily,
          fontFamilyFallback: ShadTheme.of(context)
              .textTheme
              .p
              .fontFamilyFallback,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: _Wash(service: widget.artwork, art: wash),
            ),
            LayoutBuilder(
              builder: (context, box) {
                final width = box.maxWidth;
                final wide = width >= 640;
                final heroHeight = backdrop == null
                    ? (wide ? 420.0 : 300.0)
                    : (width * 9 / 16).clamp(260.0, box.maxHeight * 0.85);
                return Stack(
                  children: [
                    if (backdrop != null)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: heroHeight,
                        child: _Hero(service: widget.artwork, art: backdrop),
                      ),
                    ListView(
                      padding: EdgeInsets.only(bottom: _M.sectionGap + 16),
                      children: [
                        Container(
                          constraints: BoxConstraints(
                            minHeight: heroHeight - 42,
                          ),
                          alignment: Alignment.bottomLeft,
                          padding: EdgeInsets.fromLTRB(
                            _M.gutter + (wide ? _M.columnInset : 0),
                            top + 72,
                            wide ? _M.rightPadding : _M.gutter,
                            0,
                          ),
                          child: wide
                              ? _wideInfo(title, fields)
                              : _narrowInfo(title, fields),
                        ),
                        const SizedBox(height: 52),
                        ..._sections(fields, title),
                      ],
                    ),
                  ],
                );
              },
            ),
            Positioned(
              top: top + AppSpacing.md + 2,
              left: AppSpacing.md,
              child: _CircleButton(
                icon: Icons.chevron_left_rounded,
                iconSize: 26,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            // Raw metadata editing is a debugging tool, hidden unless enabled.
            // The top-right corner itself belongs to the assistant button.
            if (developer)
              Positioned(
                top: top + AppSpacing.md + 2,
                right: AppSpacing.page(context).right + 40 + AppSpacing.sm,
                child: _CircleButton(
                  key: const ValueKey('media-metadata'),
                  icon: Icons.more_horiz_rounded,
                  tooltip: l.metadata,
                  onPressed: _openMetadata,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- header

  Widget _wideInfo(String title, Map<String, dynamic> fields) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      SizedBox(width: _M.columnWidth, child: _actionColumn(title)),
      const SizedBox(width: _M.columnGap),
      Expanded(child: _facts(title, fields)),
    ],
  );

  Widget _narrowInfo(String title, Map<String, dynamic> fields) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _actionColumn(title),
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      _facts(title, fields),
    ],
  );

  Widget _actionColumn(String title) {
    final playable = _series
        ? _nextEpisode() != null
        : service.resources(_id).isNotEmpty;
    final versions = !_series && service.resources(_id).length > 1;
    final favorite = service.isFavorite(_id);
    final watched = service.isWatched(_id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _titleArt(title),
        const SizedBox(height: 14),
        _GlassButton(
          height: _M.buttonHeight,
          semanticLabel: l.play,
          onPressed: !playable || _busy
              ? null
              : () {
                  final target = _series ? _nextEpisode() : _id;
                  if (target != null) _playMedia(target);
                },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow_rounded, size: 26, color: _C.text),
              const SizedBox(width: 6),
              Text(
                l.play,
                style: const TextStyle(
                  color: _C.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 17),
        Row(
          children: [
            Expanded(
              child: _GlassButton(
                height: _M.buttonHeight,
                tooltip: favorite ? l.removeFavorite : l.favorite,
                onPressed: () =>
                    setState(() => service.favorite(_id, !favorite)),
                child: Icon(
                  favorite ? Icons.favorite_rounded : LucideIcons.heart,
                  size: 19,
                  color: _C.text,
                ),
              ),
            ),
            if (versions) ...[
              const SizedBox(width: _M.buttonGap),
              Expanded(
                child: _GlassButton(
                  height: _M.buttonHeight,
                  tooltip: l.detailVersions,
                  onPressed: _busy ? null : _pickVersionAndPlay,
                  child: const Icon(
                    LucideIcons.listVideo,
                    size: 19,
                    color: _C.text,
                  ),
                ),
              ),
            ],
            const SizedBox(width: _M.buttonGap),
            Expanded(
              child: _GlassButton(
                height: _M.buttonHeight,
                tooltip: watched ? l.markUnwatched : l.markWatched,
                onPressed: service.playableResources(_id).isEmpty
                    ? null
                    : () => setState(() => service.setWatched(_id, !watched)),
                child: Icon(
                  watched ? Icons.flag_rounded : LucideIcons.flag,
                  size: 19,
                  color: _C.text,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The title logo in the UI language (or a language-neutral one), else
  /// an English logo, else the title set in large type. Logos with an
  /// opaque background box are skipped.
  Widget _titleArt(String title) {
    final logos = ArtworkService.orderedLogos(
      service.metadata.artworkCandidates(_id),
      l.localeName,
    );
    final text = Text(
      title,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _C.text,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.25,
        shadows: [Shadow(color: Color(0x66000000), blurRadius: 12)],
      ),
    );
    if (logos.isEmpty) return text;
    return Semantics(
      label: title,
      image: true,
      child: ExcludeSemantics(
        child: TitleLogo(service: widget.artwork, logos: logos, fallback: text),
      ),
    );
  }

  Widget _facts(String title, Map<String, dynamic> fields) {
    final ratings = fields['ratings'] is Map
        ? Map<String, dynamic>.from(fields['ratings'] as Map)
        : <String, dynamic>{};
    final mainSource = ratings.containsKey('tmdb')
        ? 'tmdb'
        : ratings.keys.firstOrNull;
    final mainScore = mainSource == null ? null : _score(ratings[mainSource]);
    final date = DateTime.tryParse('${fields['airDate'] ?? ''}');
    final countries = [
      for (final c in fields['countries'] as List? ?? [])
        if (c is String) countryName(c, l.localeName),
    ].take(2).join(',');
    final genres = (fields['genres'] as List? ?? []).take(4).join(',');
    final certification = fields['certification']?.toString();
    final factStyle = const TextStyle(
      color: _C.text,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
    );
    final facts = <Widget>[
      if (mainScore != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 17, color: _C.star),
            const SizedBox(width: 2),
            Text(mainScore, style: factStyle),
          ],
        ),
      if (date != null)
        Text(
          MaterialLocalizations.of(context).formatCompactDate(date),
          style: factStyle,
        )
      else if (fields['year'] != null)
        Text('${fields['year']}', style: factStyle),
      if (countries.isNotEmpty) Text(countries, style: factStyle),
      if (genres.isNotEmpty) Text(genres, style: factStyle),
      if (certification != null && certification.isNotEmpty)
        _Certification(certification),
    ];
    final runtime = fields['runtime'];
    final subline = _series
        ? _episodeCountLine()
        : (runtime is int && runtime > 0 ? l.detailRuntime(runtime) : null);
    final others = [
      for (final entry in ratings.entries)
        if (entry.key != mainSource && _score(entry.value) != null)
          _RatingBadge(source: entry.key, value: _score(entry.value)!),
    ];
    final overview = fields['overview']?.toString().trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (facts.isNotEmpty)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 2,
            children: [
              for (final (i, fact) in facts.indexed) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 9),
                    child: SizedBox(
                      height: 14,
                      child: VerticalDivider(
                        width: 1.5,
                        thickness: 1.5,
                        color: _C.divider,
                      ),
                    ),
                  ),
                fact,
              ],
            ],
          ),
        if (subline != null) ...[
          const SizedBox(height: 4),
          Text(
            subline,
            style: const TextStyle(color: _C.secondary, fontSize: 13.5),
          ),
        ],
        if (others.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 16, runSpacing: 4, children: others),
        ],
        if (overview.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Overview(
            title: title,
            overview: overview,
            onMore: () => _showOverview(title, overview),
          ),
        ],
      ],
    );
  }

  String? _episodeCountLine() {
    final episodes = _episodesOf(_season(_seasons));
    return episodes.isEmpty ? null : l.detailEpisodeCount(episodes.length);
  }

  static String? _score(dynamic rating) {
    if (rating is! Map || rating['value'] is! num) return null;
    final value = (rating['value'] as num).toDouble();
    final max = rating['max'] is num ? (rating['max'] as num).toDouble() : 10;
    if (value <= 0) return null;
    if (max == 100) return '${value.round()}%';
    final scaled = max == 10 ? value : value / max * 10;
    return scaled.toStringAsFixed(1);
  }

  void _showOverview(String title, String overview) => showShadDialog<void>(
    context: context,
    builder: (c) => ShadDialog(
      title: Text(title),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 420),
        child: SingleChildScrollView(child: Text(overview)),
      ),
    ),
  );

  // -------------------------------------------------------------- sections

  List<Widget> _sections(Map<String, dynamic> fields, String title) {
    final sections = <Widget>[
      if (_series) ..._episodeSection(),
      if (!_series) ..._collectionSection(),
      ..._castSection(fields),
      if (!_series) ..._versionSection(),
      ..._genreSection(fields),
    ];
    return [
      for (final (i, s) in sections.indexed) ...[
        if (i > 0) const SizedBox(height: _M.sectionGap),
        s,
      ],
    ];
  }

  Widget _header(Widget title, {List<Widget> trailing = const []}) => Padding(
    padding: const EdgeInsets.fromLTRB(_M.gutter, 0, _M.gutter, _M.headerGap),
    child: Row(
      children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: DefaultTextStyle.merge(style: _sectionTitle, child: title),
          ),
        ),
        ...trailing,
      ],
    ),
  );

  Widget _shelf({
    required double height,
    required int count,
    required double itemWidth,
    required double gap,
    required Widget Function(int) item,
    ScrollController? controller,
  }) => SizedBox(
    height: height,
    child: ListView.separated(
      controller: controller,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: _M.gutter),
      clipBehavior: Clip.none,
      itemCount: count,
      separatorBuilder: (_, _) => SizedBox(width: gap),
      itemBuilder: (_, i) => SizedBox(width: itemWidth, child: item(i)),
    ),
  );

  /// Height of a caption block below a card, growing with text scaling.
  double _lines(double fontSize, int lines, {double height = 1.35}) =>
      MediaQuery.textScalerOf(context).scale(fontSize) * height * lines;

  List<Widget> _episodeSection() {
    final seasons = _seasons;
    final season = _season(seasons);
    final episodes = _episodesOf(season);
    final label = season == null
        ? l.detailNoEpisodes
        : l.seasonLabel(_number(season['season']));
    final seasonTitle = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (seasons.length > 1) ...[
          const SizedBox(width: 4),
          const Icon(LucideIcons.chevronDown, size: 18, color: _C.text),
        ],
      ],
    );
    final header = _header(
      seasons.length > 1
          ? MenuAnchor(
              style: const MenuStyle(
                backgroundColor: WidgetStatePropertyAll(Color(0xF02A2A2E)),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
              ),
              menuChildren: [
                for (final s in seasons)
                  MenuItemButton(
                    onPressed: () => setState(() {
                      _seasonId = s['id'] as String;
                      _episodeChunk = 0;
                      if (_episodeScroll.hasClients) _episodeScroll.jumpTo(0);
                    }),
                    leadingIcon: SizedBox(
                      width: 18,
                      child: s['id'] == season['id']
                          ? const Icon(Icons.check, size: 16, color: _C.text)
                          : null,
                    ),
                    child: Text(
                      l.seasonLabel(_number(s['season'])),
                      style: const TextStyle(color: _C.text, fontSize: 14),
                    ),
                  ),
              ],
              builder: (context, menu, _) => _Pressable(
                onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                builder: (_) => seasonTitle,
              ),
            )
          : seasonTitle,
      trailing: [
        if (episodes.length > 3) ...[
          _GlassButton(
            width: 39,
            height: 31,
            tooltip: l.detailScrollStart,
            onPressed: () => _scrollEpisodes(0),
            child: const Icon(
              LucideIcons.arrowLeftToLine,
              size: 17,
              color: _C.text,
            ),
          ),
          const SizedBox(width: 9),
          _GlassButton(
            width: 39,
            height: 31,
            tooltip: l.detailScrollEnd,
            onPressed: () => _scrollEpisodes(double.infinity),
            child: const Icon(
              LucideIcons.arrowRightToLine,
              size: 17,
              color: _C.text,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        if (episodes.isNotEmpty)
          _Pressable(
            onPressed: () => _openEpisodeList(label, episodes),
            builder: (hover) => Text(
              l.detailViewAll,
              style: TextStyle(
                color: hover ? _C.text : _C.secondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
    if (episodes.isEmpty) {
      return [_header(Text(l.detailNoEpisodes, style: _sectionTitle))];
    }
    final chunks = (episodes.length / _M.episodeChunk).ceil();
    final stillHeight = _M.stillWidth * 9 / 16;
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          _shelf(
            controller: _episodeScroll,
            height: stillHeight + 10 + _lines(13.5, 1) + 2,
            count: episodes.length,
            itemWidth: _M.stillWidth,
            gap: _M.stillGap,
            item: (i) => _episodeCard(episodes[i]),
          ),
          if (chunks > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(_M.gutter, 22, _M.gutter, 0),
              child: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  for (var c = 0; c < chunks; c++)
                    _Chip(
                      label:
                          '${c * _M.episodeChunk + 1}-${((c + 1) * _M.episodeChunk).clamp(0, episodes.length)}',
                      selected: c == _episodeChunk.clamp(0, chunks - 1),
                      bold: true,
                      onPressed: () => _scrollEpisodes(
                        c * _M.episodeChunk * (_M.stillWidth + _M.stillGap),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ];
  }

  void _scrollEpisodes(double offset) {
    if (!_episodeScroll.hasClients) return;
    final position = _episodeScroll.position;
    _episodeScroll.animateTo(
      offset.clamp(0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _episodeCard(dynamic episode) {
    final id = episode['id'] as String;
    final number = _number(episode['episode']);
    final fields = service.metadata.fields(id);
    final title = (fields['title'] ?? episode['title']).toString();
    final still =
        service.metadata.selectedArtwork(id, type: 'thumbnail') ??
        service.metadata.displayArtwork(id);
    final resources = service.resources(id);
    final checkpoint = resources.isEmpty
        ? null
        : service.checkpoint(resources.first['id'] as String);
    final position = checkpoint?['position'];
    final duration = checkpoint?['duration'];
    final completed = checkpoint?['completed'] == 1;
    final progress =
        !completed && position is int && duration is int && duration > 0
        ? position / duration
        : null;
    return _Pressable(
      onPressed: _busy || resources.isEmpty ? null : () => _playMedia(id),
      semanticLabel: title,
      builder: (hover) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Card(
            width: _M.stillWidth,
            aspectRatio: 16 / 9,
            highlighted: hover,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (still != null)
                  MetadataArtwork(
                    service: widget.artwork,
                    artwork: still,
                    placeholder: const _ArtPlaceholder(),
                  )
                else
                  const _ArtPlaceholder(),
                if (completed)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: _Badge(icon: Icons.check_rounded),
                  ),
                if (progress != null && progress > 0)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 7,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.02, 1),
                        minHeight: 3,
                        backgroundColor: const Color(0x55FFFFFF),
                        valueColor: const AlwaysStoppedAnimation(_C.text),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            number > 0 ? '$number. $title' : title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hover ? _C.text : _C.secondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  void _openEpisodeList(String label, List<dynamic> episodes) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AppPage(
          title: Text(label),
          body: ListView(
            padding: AppSpacing.page(context),
            children: [for (final e in episodes) _episodeRow(e)],
          ),
        ),
      ),
    );
  }

  Widget _episodeRow(dynamic episode) {
    final id = episode['id'] as String;
    final number = _number(episode['episode']);
    final still = service.metadata.displayArtwork(id);
    final playable = service.resources(id).isNotEmpty;
    return Builder(
      builder: (context) => ContentRow(
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
        onTap: !playable
            ? null
            : () async {
                Navigator.of(context).pop();
                await _playMedia(id);
              },
      ),
    );
  }

  List<Widget> _collectionSection() {
    final members = service.collection(_id);
    if (members.length < 2) return const [];
    final posterHeight = _M.posterWidth * 1.5;
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(Text(l.detailCollection)),
          _shelf(
            height: posterHeight + 9 + _lines(13.5, 1) + _lines(12.5, 1) + 2,
            count: members.length,
            itemWidth: _M.posterWidth,
            gap: _M.posterGap,
            item: (i) => _posterCard(members[i]),
          ),
        ],
      ),
    ];
  }

  Widget _posterCard(dynamic media) {
    final id = media['id'] as String;
    final fields = service.metadata.fields(id);
    final title = (fields['title'] ?? media['title']).toString();
    final poster = service.metadata.displayArtwork(id);
    final ratings = fields['ratings'];
    final score = ratings is Map
        ? _score(ratings['tmdb'] ?? ratings.values.firstOrNull)
        : null;
    final date = DateTime.tryParse('${fields['airDate'] ?? ''}');
    final current = id == _id;
    return _Pressable(
      onPressed: current ? null : () => _openMedia(media),
      semanticLabel: title,
      builder: (hover) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Card(
            width: _M.posterWidth,
            aspectRatio: 2 / 3,
            highlighted: hover || current,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (poster != null)
                  MetadataArtwork(
                    service: widget.artwork,
                    artwork: poster,
                    placeholder: const _ArtPlaceholder(),
                  )
                else
                  const _ArtPlaceholder(),
                if (score != null) ...[
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0x99000000)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 7,
                    bottom: 4,
                    child: Text(
                      score,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        shadows: [
                          Shadow(color: Color(0x99000000), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.body,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          Text(
            date != null
                ? MaterialLocalizations.of(context).formatCompactDate(date)
                : '${fields['year'] ?? ''}',
            maxLines: 1,
            style: const TextStyle(
              color: _C.muted,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _castSection(Map<String, dynamic> fields) {
    final directorProfiles = fields['directorProfiles'] is Map
        ? fields['directorProfiles'] as Map
        : const {};
    final people = <({String name, String? role, String? photo})>[
      for (final d in (fields['directors'] as List? ?? []).take(2))
        if (d is String)
          (
            name: d,
            role: l.detailDirectors,
            photo: directorProfiles[d] as String?,
          ),
      for (final c in (fields['cast'] as List? ?? []).take(30))
        if (c is Map && c['name'] is String)
          (
            name: c['name'] as String,
            role: c['role'] as String?,
            photo: c['profile'] as String?,
          ),
    ];
    if (people.isEmpty) return const [];
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(Text(l.detailCastAndCrew)),
          _shelf(
            height:
                _M.avatar +
                10 +
                _lines(13.5, 1) +
                _lines(12, 2, height: 1.25) +
                2,
            count: people.length,
            itemWidth: _M.avatar,
            gap: _M.avatarGap,
            item: (i) => _person(people[i]),
          ),
        ],
      ),
    ];
  }

  Widget _person(({String name, String? role, String? photo}) person) {
    final uri = person.photo == null ? null : Uri.tryParse(person.photo!);
    final initials = person.name.trim().isEmpty
        ? '?'
        : person.name.trim().characters.first.toUpperCase();
    final fallback = ColoredBox(
      color: _C.chip,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: _C.secondary,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    return Semantics(
      label: [person.name, if (person.role != null) person.role].join(', '),
      excludeSemantics: true,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.square(
              dimension: _M.avatar,
              child: uri == null
                  ? fallback
                  : MetadataArtwork(
                      service: widget.artwork,
                      artwork: ArtworkDescriptor(
                        id: 'tmdb:profile:${uri.path.split('/').last}',
                        type: 'profile',
                        remote: uri,
                      ),
                      alignment: const Alignment(0, -0.4),
                      cacheWidth: 240,
                      placeholder: fallback,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            person.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _C.body,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (person.role != null && person.role!.isNotEmpty)
            Text(
              person.role!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _C.muted,
                fontSize: 12,
                height: 1.25,
              ),
            ),
        ],
      ),
    );
  }

  /// Movie versions, only worth listing when there are several.
  List<Widget> _versionSection() {
    final resources = service.resources(_id);
    if (resources.length < 2) return const [];
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(Text(l.detailVersions)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _M.gutter),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final resource in resources)
                  _Pressable(
                    onPressed: _busy ? null : () => _play(resource),
                    semanticLabel: resource['name'] as String,
                    builder: (hover) => AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 280,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: hover ? _C.chip : _C.tile,
                        borderRadius: BorderRadius.circular(_M.cardRadius),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.play_circle_outline_rounded,
                            size: 22,
                            color: _C.secondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  resource['name'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _C.body,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.35,
                                  ),
                                ),
                                Text(
                                  widget.resourceLabel(resource),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _C.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _genreSection(Map<String, dynamic> fields) {
    final genres = [
      for (final g in fields['genres'] as List? ?? [])
        if (g is String && g.isNotEmpty) g,
    ];
    if (genres.isEmpty) return const [];
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(Text(l.detailGenres)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _M.gutter),
            child: Wrap(
              spacing: 11.5,
              runSpacing: AppSpacing.sm,
              children: [for (final g in genres) _Chip(label: g)],
            ),
          ),
        ],
      ),
    ];
  }
}

// ------------------------------------------------------------- backgrounds

/// The page background: the artwork scaled up and blurred into a colour wash,
/// darkened enough for white text.
class _Wash extends StatelessWidget {
  const _Wash({required this.service, required this.art});
  final ArtworkService service;
  final ArtworkDescriptor? art;

  @override
  Widget build(BuildContext context) {
    if (art == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A2C33), _C.base],
          ),
        ),
      );
    }
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: 70,
              sigmaY: 70,
              tileMode: TileMode.mirror,
            ),
            child: MetadataArtwork(
              service: service,
              artwork: art!,
              cacheWidth: 96,
              fadeIn: true,
              placeholder: const ColoredBox(color: _C.base),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x8C000000)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The full-width backdrop, fading out at the bottom into the wash and
/// darkened bottom-left where the title and buttons sit.
class _Hero extends StatelessWidget {
  const _Hero({required this.service, required this.art});
  final ArtworkService service;
  final ArtworkDescriptor art;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        stops: [0, 0.6, 1],
      ).createShader(rect),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MetadataArtwork(
            service: service,
            artwork: art,
            alignment: const Alignment(0, -0.35),
            cacheWidth: null,
            fadeIn: true,
            placeholder: const SizedBox.shrink(),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33000000),
                  Color(0x00000000),
                  Color(0x59000000),
                ],
                stops: [0, 0.3, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.85, 0.75),
                radius: 1.0,
                colors: [Color(0x59000000), Color(0x00000000)],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------- controls

/// Hover/focus/press handling shared by the page's custom controls.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.onPressed,
    required this.builder,
    this.semanticLabel,
  });
  final VoidCallback? onPressed;
  final Widget Function(bool highlighted) builder;
  final String? semanticLabel;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onPressed?.call(),
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: widget.builder(enabled && (_hover || _focus)),
        ),
      ),
    );
  }
}

/// Frosted translucent pill used for play and the icon actions.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.onPressed,
    required this.child,
    this.height = _M.buttonHeight,
    this.width,
    this.tooltip,
    this.semanticLabel,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final double? width;
  final String? tooltip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final button = _Pressable(
      onPressed: onPressed,
      semanticLabel: semanticLabel ?? tooltip,
      builder: (hover) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: width,
            constraints: BoxConstraints(minHeight: height),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hover ? _C.glassHover : _C.glass,
              borderRadius: BorderRadius.circular(height),
              border: Border.all(color: const Color(0x14FFFFFF)),
            ),
            child: Opacity(opacity: onPressed == null ? 0.45 : 1, child: child),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// Round dark button floating over the artwork (back, more).
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 22,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: _Pressable(
      onPressed: onPressed,
      semanticLabel: tooltip,
      builder: (hover) => ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hover ? const Color(0x80000000) : const Color(0x52000000),
            ),
            child: Icon(icon, size: iconSize, color: _C.text),
          ),
        ),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.onPressed,
    this.selected = false,
    this.bold = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final bool bold;

  @override
  Widget build(BuildContext context) => _Pressable(
    onPressed: onPressed,
    semanticLabel: label,
    builder: (hover) => AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      constraints: const BoxConstraints(minHeight: 30, minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: selected || hover ? _C.chipHover : _C.chip,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected ? _C.text : _C.secondary,
          fontSize: 13.5,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    ),
  );
}

/// Rounded artwork frame that gains a white outline on hover or focus.
class _Card extends StatelessWidget {
  const _Card({
    required this.width,
    required this.aspectRatio,
    required this.child,
    this.highlighted = false,
  });
  final double width;
  final double aspectRatio;
  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: width,
    height: width / aspectRatio,
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(_M.cardRadius),
      border: Border.all(
        color: highlighted ? _C.text : const Color(0x1AFFFFFF),
        width: highlighted ? 2.5 : 1,
      ),
    ),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(_M.cardRadius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 14,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(_M.cardRadius),
      child: ColoredBox(color: const Color(0xFF26272B), child: child),
    ),
  );
}

class _ArtPlaceholder extends StatelessWidget {
  const _ArtPlaceholder();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF2A2B30),
    child: Center(
      child: Icon(LucideIcons.clapperboard, size: 28, color: _C.muted),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: const BoxDecoration(
      color: Color(0xCC000000),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: 15, color: _C.text),
  );
}

class _Certification extends StatelessWidget {
  const _Certification(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: _C.text, width: 1.3),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      value,
      style: const TextStyle(
        color: _C.text,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
    ),
  );
}

/// A score with its source mark: IMDb's yellow tag, TMDB's teal one, or the
/// source name in small caps for anything else.
class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.source, required this.value});
  final String source;
  final String value;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (source.toLowerCase()) {
      'imdb' => ('IMDb', const Color(0xFFF5C518), const Color(0xFF000000)),
      'tmdb' || 'themoviedb' => (
        'TMDB',
        const Color(0xFF01B4E4),
        const Color(0xFF0D253F),
      ),
      'douban' => ('豆瓣', const Color(0xFF00B51D), _C.text),
      'trakt' => ('trakt', const Color(0xFFED1C24), _C.text),
      'rottentomatoes' ||
      'tomatometer' => ('RT', const Color(0xFFFA320A), _C.text),
      _ => (source.toUpperCase(), _C.chip, _C.text),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: _C.body,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

/// Three lines of overview led by 「title」; tapping opens the full text.
class _Overview extends StatelessWidget {
  const _Overview({
    required this.title,
    required this.overview,
    required this.onMore,
  });
  final String title;
  final String overview;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => _Pressable(
    onPressed: onMore,
    builder: (hover) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '「$title」',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: overview),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: hover ? _C.text : _C.body,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
    ),
  );
}
