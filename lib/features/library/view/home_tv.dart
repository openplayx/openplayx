part of 'home_page.dart';

extension _TvHome on _HomePageState {
  Widget _tvHero(dynamic media) {
    final id = media['id'] as String;
    final fields = widget.service.metadata.fields(id);
    final title = (fields['title'] ?? media['title']).toString();
    final art = widget.service.metadata.selectedArtwork(id, type: 'backdrop');
    final colors = ShadTheme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: art == null
                  ? ColoredBox(color: colors.muted)
                  : MetadataArtwork(
                      service: _artwork,
                      artwork: art,
                      cacheWidth: 1600,
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.background.withValues(alpha: .96),
                      colors.background.withValues(alpha: .35),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 220,
                  maxWidth: 620,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppLocalizations.of(context).recentlyAdded,
                      style: TextStyle(color: colors.primary, fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (fields['overview'] case final String overview
                        when overview.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    TvAction(
                      key: const ValueKey('tv-home-featured'),
                      autofocus: _shelves.continueWatching.isEmpty,
                      onPressed: () => openDetail(media),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(AppIcons.info, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context).tvViewDetails,
                            style: const TextStyle(fontSize: 20),
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
    );
  }
}
