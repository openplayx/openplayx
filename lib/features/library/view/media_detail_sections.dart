part of 'media_detail_page.dart';

/// The sections of the detail page: title block, facts, actions, episodes,
/// extras, collection, cast and genres.
extension _DetailSections on _MediaDetailPageState {
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
    final playable = _c.playable;
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
                  final target = _series ? _c.nextEpisode() : _id;
                  if (target != null) unawaited(_playMedia(target));
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
    final episodes = _c.episodesOf(_c.selectedSeason(_c.seasons));
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
      ..._extrasSection(),
      ..._castSection(fields),
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
    final seasons = _c.seasons;
    final season = _c.selectedSeason(seasons);
    final episodes = _c.episodesOf(season);
    final label = season == null
        ? l.detailNoEpisodes
        : l.seasonLabel(season.season ?? 0);
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
                    onPressed: () {
                      _update(() => _episodeChunk = 0);
                      if (_episodeScroll.hasClients) _episodeScroll.jumpTo(0);
                      _c.selectSeason(s.id);
                    },
                    leadingIcon: SizedBox(
                      width: 18,
                      child: s.id == season?.id
                          ? const Icon(Icons.check, size: 16, color: _C.text)
                          : null,
                    ),
                    child: Text(
                      l.seasonLabel(s.season ?? 0),
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

  List<Widget> _extrasSection() {
    final extras = _c.extras;
    if (extras.isEmpty) return const [];
    final stillHeight = _M.stillWidth * 9 / 16;
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(Text(l.detailExtras)),
          _shelf(
            height: stillHeight + 10 + _lines(13.5, 1) + 2,
            count: extras.length,
            itemWidth: _M.stillWidth,
            gap: _M.stillGap,
            item: (i) => _episodeCard(
              extras[i],
              label:
                  service.metadata.fields(extras[i].id)['title'] as String? ??
                  MediaDetailController.extraTitle(extras[i].title),
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

  Widget _episodeCard(MediaItem episode, {String? label}) {
    final id = episode.id;
    final number = episode.episode ?? 0;
    final fields = service.metadata.fields(id);
    final title = label ?? (fields['title'] ?? episode.title).toString();
    final still =
        service.metadata.selectedArtwork(id, type: 'thumbnail') ??
        service.metadata.displayArtwork(id);
    final resources = _c.versions(id);
    // Progress of whichever version was played last.
    final checkpoint = _c.latestProgress(id);
    final progress =
        checkpoint != null &&
            !checkpoint.completed &&
            checkpoint.duration > Duration.zero
        ? checkpoint.position.inMilliseconds /
              checkpoint.duration.inMilliseconds
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
                if (checkpoint?.completed ?? false)
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

  void _openEpisodeList(String label, List<MediaItem> episodes) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'AppPage'),
        builder: (_) => AppPage(
          pageContext: PageContextData(
            pageType: 'episode_list',
            entity: {'media_id': _id},
            state: {'episodeCount': episodes.length},
          ),
          title: Text(label),
          body: ListView(
            padding: AppSpacing.page(context),
            children: [for (final e in episodes) _episodeRow(e)],
          ),
        ),
      ),
    );
  }

  Widget _episodeRow(MediaItem episode) {
    final id = episode.id;
    final number = episode.episode ?? 0;
    final still = service.metadata.displayArtwork(id);
    final playable = _c.versions(id).isNotEmpty;
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
              ? '${l.episodeLabel(number)}  ${episode.title}'
              : episode.title,
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
    final members = _c.collection;
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

  Widget _posterCard(MediaItem media) {
    final id = media.id;
    final fields = service.metadata.fields(id);
    final title = (fields['title'] ?? media.title).toString();
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
        : const <Object?, Object?>{};
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
