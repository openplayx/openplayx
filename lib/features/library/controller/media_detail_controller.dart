import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../capabilities/library/library_service.dart';
import '../../../capabilities/library/media_models.dart';

/// A season with the episodes of it that can be played.
typedef EpisodeGroup = ({MediaItem? season, List<MediaItem> episodes});

/// One movie or series page: its seasons, episodes, extras, versions and
/// progress and watched state. Follows library changes
/// (background scraping publishes titles, artwork and episodes).
class MediaDetailController extends ChangeNotifier {
  MediaDetailController({required this.service, required dynamic media})
    : item = MediaItem.fromRow(media) {
    // Opening a detail page makes this item (and its episodes) top priority.
    service.prioritizeMetadata([
      id,
      for (final c in service.childItems(id, limit: 50)) c.id,
    ]);
    _changes = service.changes.listen((_) => _notify());
  }

  final LibraryService service;
  final MediaItem item;
  String get id => item.id;
  StreamSubscription<void>? _changes;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static bool isSeries(LibraryService service, String id) {
    final kind = service.metadata.fields(id)['kind'];
    if (kind == 'series' || kind == 'season') return true;
    if (kind == 'movie' || kind == 'episode') return false;
    return service.children(id, limit: 1).isNotEmpty;
  }

  late final bool series = isSeries(service, id);

  /// Scraped metadata (free-form JSON fields).
  Map<String, dynamic> get fields => service.metadata.fields(id);
  String get title => (fields['title'] ?? item.title).toString();

  // ---- Seasons, episodes, extras ----------------------------------------------

  List<MediaItem> get _children => service.childItems(id, limit: 500);

  List<MediaItem> get seasons => [
    for (final c in _children)
      if (c.isSeason) c,
  ]..sort((a, b) => (a.season ?? 0).compareTo(b.season ?? 0));

  String? _seasonId;

  /// The chosen season, else the first.
  MediaItem? selectedSeason(List<MediaItem> seasons) => seasons.isEmpty
      ? null
      : seasons.firstWhere(
          (s) => s.id == _seasonId,
          orElse: () => seasons.first,
        );

  void selectSeason(String id) {
    _seasonId = id;
    _notify();
  }

  /// Episodes of [season], or the series' own episodes without seasons.
  List<MediaItem> episodesOf(MediaItem? season) => [
    ...(season == null
        ? _children.where((c) => !c.isExtra)
        : service.childItems(season.id, limit: 500)),
  ]..sort((a, b) => (a.episode ?? 0).compareTo(b.episode ?? 0));

  List<MediaItem> get extras => [
    for (final c in _children)
      if (c.isExtra) c,
  ];

  /// "Show - S01 Extra - Making Of.mkv" shows as "Making Of".
  static String extraTitle(String name) {
    final stem = name.replaceFirst(
      RegExp(r'\.[a-z0-9]{2,5}$', caseSensitive: false),
      '',
    );
    final marker = RegExp(
      r'^.*?\b(?:S|Season\s*)\d{1,2}\s*Extras?\b[\s\d]*[-–:]?\s*',
      caseSensitive: false,
    ).firstMatch(stem);
    final rest = marker == null ? stem : stem.substring(marker.end).trim();
    return rest.isEmpty ? stem : rest;
  }

  /// Seasons with their playable episodes (seasonless series: one group).
  List<EpisodeGroup> playableEpisodes() {
    final seasons = this.seasons;
    return [
      for (final season in seasons.isEmpty ? [null] : seasons)
        (
          season: season,
          episodes: episodesOf(season)
              .where((e) => versions(e.id).isNotEmpty)
              .toList(),
        ),
    ].where((g) => g.episodes.isNotEmpty).toList();
  }

  /// The episode the play button starts: one in progress, else the first
  /// unfinished, else the first.
  String? nextEpisode() {
    final episodes = [for (final g in playableEpisodes()) ...g.episodes];
    if (episodes.isEmpty) return null;
    WatchProgress? state(MediaItem e) =>
        service.progressOf(versions(e.id).first.id);
    for (final e in episodes) {
      if (state(e)?.inProgress ?? false) return e.id;
    }
    for (final e in episodes) {
      if (!(state(e)?.completed ?? false)) return e.id;
    }
    return episodes.first.id;
  }

  // ---- Versions and progress --------------------------------------------------

  List<MediaVersion> versions(String media) => service.versionList(media);

  /// The most recent progress over [media]'s versions.
  WatchProgress? latestProgress(String media) {
    WatchProgress? latest;
    for (final v in versions(media)) {
      final p = service.progressOf(v.id);
      if (p != null && (latest == null || p.updatedAt > latest.updatedAt)) {
        latest = p;
      }
    }
    return latest;
  }

  /// The media whose versions the debug tools use: the movie itself, or the
  /// episode the play button would start.
  String? get snapshotMedia => series ? nextEpisode() : id;
  bool get debuggable {
    final media = snapshotMedia;
    return media != null && versions(media).isNotEmpty;
  }

  bool get playable => series ? nextEpisode() != null : versions(id).isNotEmpty;

  List<MediaItem> get collection => service.collectionItems(id);

  // ---- Watched -------------------------------------------------------------

  bool get watched => service.isWatched(id);

  /// Watched can be marked once something can be played.
  bool get canMarkWatched => service.playableResources(id).isNotEmpty;
  void toggleWatched() {
    service.setWatched(id, !watched);
    _notify();
  }

  // ---- Playing ---------------------------------------------------------------

  bool _busy = false;
  bool get busy => _busy;

  /// Runs [play] unless a play is already starting.
  Future<void> play(Future<void> Function() play) async {
    if (_busy) return;
    _busy = true;
    _notify();
    try {
      await play();
    } finally {
      _busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_changes?.cancel());
    super.dispose();
  }
}
