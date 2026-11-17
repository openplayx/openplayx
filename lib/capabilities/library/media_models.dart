import 'package:flutter/foundation.dart';

import '../../core/capabilities/source_capability.dart';

/// A movie, series, season, episode or extra in the library.
@immutable
class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    this.kind,
    this.season,
    this.episode,
  });

  factory MediaItem.fromRow(dynamic row) => MediaItem(
    id: row['id'] as String,
    title: (row['title'] ?? '').toString(),
    kind: row['kind'] as String?,
    season: row['season'] is int ? row['season'] as int : null,
    episode: row['episode'] is int ? row['episode'] as int : null,
  );

  final String id;

  /// Stored title (file-derived until scraped; metadata may name it better).
  final String title;
  final String? kind;
  final int? season;
  final int? episode;

  bool get isSeason => kind == 'season';
  bool get isEpisode => kind == 'episode';

  /// Bonus clips filed under a movie or series: neither season nor episode.
  bool get isExtra => !isSeason && !isEpisode;

  /// The row shape older APIs still take.
  Map<String, Object?> toRow() => {
    'id': id,
    'title': title,
    'kind': kind,
    'season': season,
    'episode': episode,
  };
}

/// One file a media item plays from.
@immutable
class MediaVersion {
  const MediaVersion({
    required this.id,
    required this.name,
    required this.ref,
    this.mediaId,
    this.size,
  });

  factory MediaVersion.fromRow(dynamic row) => MediaVersion(
    id: row['id'] as String,
    name: row['name'] as String,
    ref: ResourceRef(row['source'] as String, row['item'] as String),
    mediaId: row['media_id'] as String?,
    size: row['size'] is int ? row['size'] as int : null,
  );

  /// Library resource id.
  final String id;
  final String name;

  /// Where it is: the connection (or `@local`) and the item within it.
  final ResourceRef ref;
  final String? mediaId;

  /// File size in bytes, when known.
  final int? size;
}

/// How far a version was watched.
@immutable
class WatchProgress {
  const WatchProgress({
    required this.position,
    required this.duration,
    required this.completed,
    required this.updatedAt,
  });

  factory WatchProgress.fromRow(dynamic row) => WatchProgress(
    position: Duration(milliseconds: row['position'] as int? ?? 0),
    duration: Duration(milliseconds: row['duration'] as int? ?? 0),
    completed: row['completed'] == 1,
    updatedAt: row['updated_at'] as int? ?? 0,
  );

  final Duration position;
  final Duration duration;
  final bool completed;

  /// Milliseconds since the epoch.
  final int updatedAt;

  bool get inProgress => !completed && position > Duration.zero;
}
