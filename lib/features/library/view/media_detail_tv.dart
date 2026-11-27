part of 'media_detail_page.dart';

/// Remote presentation shares the detail controller, resource resolution,
/// progress and season selection with desktop/mobile.
extension _TvMediaDetail on _MediaDetailPageState {
  Widget _tvDetail() {
    final fields = _fields;
    final art =
        service.metadata.selectedArtwork(_id, type: 'backdrop') ??
        service.metadata.selectedArtwork(_id);
    final target = _series ? _c.nextEpisode() : _id;
    final seasons = _c.seasons;
    final season = _c.selectedSeason(seasons);
    final episodes = _series ? _c.episodesOf(season) : <MediaItem>[];
    final progress = target == null ? null : _c.latestProgress(target);
    final versions = target == null ? <MediaVersion>[] : _c.versions(target);
    return PageContextScope(
      data: PageContextData(
        pageType: 'media_detail',
        title: _c.title,
        entity: {'media_id': _id, 'kind': fields['kind']},
      ),
      child: Scaffold(
        backgroundColor: _C.base,
        body: DefaultTextStyle.merge(
          style: const TextStyle(color: _C.text),
          child: Stack(
            children: [
              if (art != null)
                Positioned.fill(
                  child: _Hero(service: widget.artwork, art: art),
                ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xF0121214), Color(0x80121214)],
                    ),
                  ),
                ),
              ),
              FocusTraversalGroup(
                child: ListView(
                  key: PageStorageKey('tv-detail-$_id'),
                  padding: const EdgeInsets.all(40),
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TvAction(
                        key: const ValueKey('tv-detail-back'),
                        label: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Icon(AppIcons.back, color: _C.text),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      _c.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      [
                        if (fields['year'] != null) '${fields['year']}',
                        if (fields['genres'] is List)
                          (fields['genres'] as List).join(' · '),
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: 20, color: _C.secondary),
                    ),
                    if (fields['overview'] case final String overview
                        when overview.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Text(
                          overview,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            color: _C.secondary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 18,
                      runSpacing: 12,
                      children: [
                        TvAction(
                          key: const ValueKey('tv-detail-play'),
                          autofocus: _c.playable,
                          onPressed: !_c.playable || _busy || target == null
                              ? null
                              : () => _playMedia(target),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                AppIcons.play,
                                color: _C.text,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                progress?.inProgress == true
                                    ? l.continueWatching
                                    : l.play,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ],
                          ),
                        ),
                        if (versions.length > 1)
                          TvAction(
                            onPressed: _busy
                                ? null
                                : () async {
                                    final picked = await _chooseVersion(
                                      target!,
                                    );
                                    if (picked != null && mounted)
                                      await _play(picked);
                                  },
                            child: Text(
                              l.detailVersions,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                      ],
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 16),
                      Text(l.loading, key: const ValueKey('media-opening')),
                    ],
                    if (!_c.playable)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: TvAction(
                          autofocus: true,
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: Text(
                            MaterialLocalizations.of(context).backButtonTooltip,
                          ),
                        ),
                      ),
                    if (seasons.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final s in seasons)
                            TvAction(
                              key: ValueKey('tv-season-${s.id}'),
                              selected: season?.id == s.id,
                              onPressed: () => _c.selectSeason(s.id),
                              child: Text(
                                s.title,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (episodes.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final e in episodes)
                            SizedBox(
                              width: 280,
                              child: TvAction(
                                key: ValueKey('tv-episode-${e.id}'),
                                onPressed: _busy || _c.versions(e.id).isEmpty
                                    ? null
                                    : () => _playMedia(e.id),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l.seasonEpisodeShort(
                                        e.season ?? 1,
                                        e.episode ?? 1,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: _C.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (!_series && versions.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      Text(
                        l.detailVersions,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 12),
                      for (final version in versions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TvAction(
                            onPressed: _busy ? null : () => _play(version),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  version.name,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                Text(
                                  _versionLabel(version),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: _C.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
