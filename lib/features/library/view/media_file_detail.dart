part of 'media_detail_page.dart';

/// A video-first layout for files without catalog information. Uses only
/// known file data, including the generated video cover when available.
extension _FileDetails on _MediaDetailPageState {
  Widget _fileDetails(
    String title,
    ArtworkDescriptor? cover,
    double top,
    bool wide,
  ) {
    final versions = _c.versions(_id);
    final progress = _c.latestProgress(_id);
    final continuing = progress?.inProgress ?? false;
    final playLabel = continuing ? l.continueWatching : l.play;
    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _fileCoverPlaceholder(),
            if (cover != null)
              MetadataArtwork(
                service: widget.artwork,
                artwork: cover,
                cacheWidth: 1200,
                fadeIn: true,
                placeholder: _fileCoverPlaceholder(),
              ),
          ],
        ),
      ),
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.detailVideoFile,
          style: const TextStyle(color: _C.secondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        // File and online-video titles often carry all the useful context.
        Text(
          title,
          key: const ValueKey('media-file-title'),
          style: const TextStyle(
            color: _C.text,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l.detailNoCatalogInfo,
          style: const TextStyle(
            color: _C.secondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        if (progress != null && progress.duration > Duration.zero) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.detailPlaybackProgress,
                  style: const TextStyle(color: _C.secondary, fontSize: 12),
                ),
              ),
              Text(
                '${_fileTime(progress.position)} / ${_fileTime(progress.duration)}',
                style: const TextStyle(color: _C.secondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value:
                  (progress.position.inMilliseconds /
                          progress.duration.inMilliseconds)
                      .clamp(0.0, 1.0),
              minHeight: 3,
              color: _C.text,
              backgroundColor: _C.chip,
            ),
          ),
        ],
        const SizedBox(height: 24),
        _GlassButton(
          height: 48,
          semanticLabel: playLabel,
          onPressed: !_c.playable || _busy ? null : () => _playMedia(_id),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow_rounded, color: _C.text, size: 26),
              const SizedBox(width: 8),
              Text(
                playLabel,
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
    return ListView(
      key: const ValueKey('media-file-details'),
      padding: EdgeInsets.fromLTRB(
        _M.gutter,
        top + 82,
        _M.gutter,
        MediaQuery.paddingOf(context).bottom + 36,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: preview),
                      const SizedBox(width: 32),
                      Expanded(flex: 4, child: info),
                    ],
                  )
                else ...[
                  preview,
                  const SizedBox(height: 24),
                  info,
                ],
                if (versions.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Text(l.detailFiles, style: _sectionTitle),
                  const SizedBox(height: 12),
                  for (final version in versions) ...[
                    _fileResource(version),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fileCoverPlaceholder() => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF455467), Color(0xFF1D252F)],
      ),
    ),
    child: Center(
      child: Icon(Icons.video_file_outlined, color: _C.muted, size: 52),
    ),
  );

  Widget _fileResource(MediaVersion version) => _Pressable(
    semanticLabel: '${l.play}: ${version.name}',
    onPressed: _busy ? null : () => _play(version),
    builder: (highlighted) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? _C.chipHover : _C.chip,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            color: _C.secondary,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  version.name,
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                if (_versionLabel(version).isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    _versionLabel(version),
                    style: const TextStyle(
                      color: _C.secondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.play_circle_outline_rounded,
            color: _C.secondary,
            size: 24,
          ),
        ],
      ),
    ),
  );

  String _fileTime(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 1 << 31);
    final minutes = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return seconds >= 3600
        ? '${seconds ~/ 3600}:$minutes:$remainder'
        : '$minutes:$remainder';
  }
}
