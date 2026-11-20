import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../settings/app_theme_controller.dart';
import '../../../core/capabilities/metadata_capability.dart';
import '../../../capabilities/sources/source_manager.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../capabilities/media_processing/media_processing_service.dart';
import '../../../capabilities/artwork/artwork_service.dart';
import '../../../capabilities/library/library_service.dart';
import '../../../capabilities/library/media_models.dart';
import '../controller/media_detail_controller.dart';
import '../../../ui/adaptive/app_page.dart';
import '../../../ui/adaptive/assistant_action.dart';
import '../../../ui/components/media/content_row.dart';
import '../../../ui/icons/app_icons.dart';
import '../../../ui/tokens/app_spacing.dart';
import 'country_names.dart';
import 'audio_subtitle_debug_page.dart';
import 'ffmpeg_snapshot_debug_page.dart';
import '../../../capabilities/speech/subtitle_generation_service.dart';
import 'metadata_artwork.dart';
import 'metadata_page.dart';
import 'title_logo.dart';
import '../../../core/format/byte_size.dart';

part 'media_detail_sections.dart';
part 'media_detail_widgets.dart';
part 'media_file_detail.dart';

/// Plays one resource of a media item; supplied by the library page.
typedef PlayResource = Future<void> Function(
  BuildContext context,
  MediaVersion version,
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
  final String Function(MediaVersion version) resourceLabel;

  static bool isSeries(LibraryService service, String id) =>
      MediaDetailController.isSeries(service, id);

  @override
  State<MediaDetailPage> createState() => _MediaDetailPageState();
}

class _MediaDetailPageState extends State<MediaDetailPage> {
  AppLocalizations get l => AppLocalizations.of(context);
  LibraryService get service => widget.service;
  late final MediaDetailController _c = MediaDetailController(
    service: widget.service,
    media: widget.media,
  )..addListener(_changed);
  String get _id => _c.id;
  bool get _busy => _c.busy;
  final _episodeScroll = ScrollController();
  int _episodeChunk = 0;

  Map<String, dynamic> get _fields => _c.fields;
  bool get _series => _c.series;

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _episodeScroll.addListener(_trackEpisodeChunk);
  }

  @override
  void dispose() {
    _c.dispose();
    _episodeScroll.dispose();
    super.dispose();
  }

  void _trackEpisodeChunk() {
    final stride = _M.stillWidth + _M.stillGap;
    final chunk = (_episodeScroll.offset / stride + 0.5) ~/ _M.episodeChunk;
    if (chunk != _episodeChunk) setState(() => _episodeChunk = chunk);
  }

  Future<void> _play(MediaVersion version) =>
      _c.play(() => widget.play(context, version));

  /// File size (when known) and where the version plays from.
  String _versionLabel(MediaVersion version) {
    final size = version.size;
    final label = widget.resourceLabel(version);
    if (size == null) return label;
    return label.isEmpty ? formatBytes(size) : '${formatBytes(size)} · $label';
  }

  /// Plays a media item, asking which version when it has several, largest
  /// first.
  Future<void> _playMedia(String media) async {
    final versions = _c.versions(media);
    if (versions.isEmpty) return;
    if (versions.length == 1) return _play(versions.first);
    final picked = await _chooseVersion(media);
    if (picked != null && mounted) await _play(picked);
  }

  Future<MediaVersion?> _chooseVersion(String media) =>
      showShadDialog<MediaVersion>(
        context: context,
        builder: (c) => ShadDialog(
          title: Text(l.chooseVersion),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 360),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final version in _c.versions(media))
                  ContentRow(
                    leading: Icon(AppIcons.playMedia),
                    title: Text(version.name),
                    subtitle: Text(_versionLabel(version)),
                    onTap: () => Navigator.pop(c, version),
                  ),
              ],
            ),
          ),
        ),
      );

  Future<void> _openMetadata() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            MetadataPage(library: service, sources: widget.sources, media: _id),
      ),
    );
    if (mounted) setState(() {});
  }

  bool get _debuggable => _c.debuggable;

  Future<void> _openSnapshotDebug() async {
    final media = _c.snapshotMedia;
    if (media == null || _busy) return;
    final versions = _c.versions(media);
    if (versions.isEmpty) return;
    // Keep the chosen version; ask only when several exist. Never re-pick.
    final version = versions.length == 1
        ? versions.first
        : await _chooseVersion(media);
    if (version == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FfmpegSnapshotDebugPage(
          service: MediaProcessingService.current,
          resource: version.ref,
          title: version.name,
        ),
      ),
    );
  }

  /// Series/season: choose a season and an episode first; a whole series
  /// is never processed as one video (design §3.1).
  Future<MediaItem?> _pickEpisode() async {
    final groups = _c.playableEpisodes();
    if (groups.isEmpty) return null;
    return showShadDialog<MediaItem>(
      context: context,
      builder: (c) => ShadDialog(
        title: Text(l.asrChooseEpisode),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 420),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final (:season, :episodes) in groups) ...[
                if (season != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                    child: Text(
                      l.seasonLabel(season.season ?? 0),
                      style: ShadTheme.of(c).textTheme.small,
                    ),
                  ),
                for (final e in episodes)
                  ContentRow(
                    key: ValueKey('asr-episode-${e.id}'),
                    title: Text(
                      (e.episode ?? 0) > 0
                          ? '${l.episodeLabel(e.episode!)}  ${e.title}'
                          : e.title,
                    ),
                    onTap: () => Navigator.pop(c, e),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAudioSubtitleDebug() async {
    if (_busy) return;
    MediaItem? episode;
    var media = _id;
    if (_series) {
      episode = await _pickEpisode();
      if (episode == null || !mounted) return;
      media = episode.id;
    }
    final versions = _c.versions(media);
    if (versions.isEmpty) return;
    // Show the chosen version explicitly; never switch sources silently.
    final version = versions.length == 1
        ? versions.first
        : await _chooseVersion(media);
    if (version == null || !mounted) return;
    String? episodeLabel;
    if (episode != null) {
      final season = service.metadata.fields(media)['season'];
      final number = episode.episode ?? 0;
      episodeLabel = [
        if (season is int) l.seasonLabel(season),
        if (number > 0) l.episodeLabel(number),
        episode.title,
      ].join(' · ');
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AudioSubtitleDebugPage(
          service: SubtitleGenerationService.current,
          target: AudioSubtitleTarget(
            resource: version.ref,
            title: _c.title,
            resourceName: version.name,
            episodeLabel: episodeLabel,
            versionLabel: '${version.name} · ${widget.resourceLabel(version)}',
          ),
        ),
      ),
    );
  }

  void _openMedia(MediaItem media) {
    if (media.id == _id) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MediaDetailPage(
          service: service,
          sources: widget.sources,
          artwork: widget.artwork,
          media: media.toRow(),
          play: widget.play,
          resourceLabel: widget.resourceLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fields;
    final title = _c.title;
    final backdrop =
        service.metadata.selectedArtwork(_id, type: 'backdrop') ??
        service.metadata.selectedArtwork(_id, type: 'thumbnail');
    final poster = service.metadata.selectedArtwork(_id);
    final wash = backdrop ?? poster;
    final developer = AppAppearance.maybeOf(context)?.developerMode ?? false;
    final top = MediaQuery.paddingOf(context).top;
    final assistant = AssistantAction.maybeOf(context);
    return PageContextScope(
      data: PageContextData(
        pageType: 'media_detail',
        title: title,
        entity: {'media_id': _id, 'kind': fields['kind']},
        state: {
          'watched': _c.watched,
          'isSeries': _series,
          'playable': _c.playable,
        },
      ),
      child: Scaffold(
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
                  if (_c.usesFileDetails) {
                    return _fileDetails(title, backdrop ?? poster, top, wide);
                  }
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
              // Resolving a remote file can take seconds; show it instead of
              // silently ignoring taps. The back button stays usable above it.
              if (_busy)
                Positioned.fill(
                  child: ColoredBox(
                    key: const ValueKey('media-opening'),
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox.square(
                            dimension: 32,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(l.loading),
                        ],
                      ),
                    ),
                  ),
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
              if (assistant != null)
                Positioned(
                  top: top + AppSpacing.md + 2,
                  right: AppSpacing.md,
                  child: AssistantButton(
                    builder: (context, action) => _CircleButton(
                      icon: AppIcons.assistant,
                      iconSize: 20,
                      onPressed: () => action.open(context),
                    ),
                  ),
                ),
              // Raw metadata editing is a debugging tool, hidden unless enabled.
              if (developer)
                Positioned(
                  top: top + AppSpacing.md + 2,
                  right:
                      AppSpacing.md +
                      (assistant != null ? 36 + AppSpacing.sm : 0),
                  child: _CircleButton(
                    key: const ValueKey('media-metadata'),
                    icon: Icons.more_horiz_rounded,
                    tooltip: l.metadata,
                    onPressed: _openMetadata,
                  ),
                ),
              // FFmpeg random-snapshot debug entry (developer tool, §9.1).
              if (developer && _debuggable)
                Positioned(
                  top: top + AppSpacing.md + 2,
                  right:
                      AppSpacing.md +
                      (assistant != null ? 36 + AppSpacing.sm : 0) +
                      36 +
                      AppSpacing.sm,
                  child: _CircleButton(
                    key: const ValueKey('media-ffmpeg-snapshot'),
                    icon: Icons.camera_alt_outlined,
                    iconSize: 18,
                    tooltip: l.ffmpegSnapshotDebug,
                    onPressed: _openSnapshotDebug,
                  ),
                ),
              // Audio extraction / subtitle recognition debug (developer, §3).
              if (developer && _debuggable)
                Positioned(
                  top: top + AppSpacing.md + 2,
                  right:
                      AppSpacing.md +
                      (assistant != null ? 36 + AppSpacing.sm : 0) +
                      (36 + AppSpacing.sm) * 2,
                  child: _CircleButton(
                    key: const ValueKey('media-audio-subtitle-debug'),
                    icon: Icons.subtitles_outlined,
                    iconSize: 18,
                    tooltip: l.asrDebugTitle,
                    onPressed: _openAudioSubtitleDebug,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- header

  /// setState for the section builders in the part files.
  void _update(VoidCallback fn) => setState(fn);
}
