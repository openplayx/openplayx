import 'package:flutter/foundation.dart';

/// Rows of the home shelves (library rows, as the tiles take them).
@immutable
class HomeShelves {
  const HomeShelves({
    this.continueWatching = const [],
    this.recentlyAdded = const [],
    this.movies = const [],
    this.series = const [],
  });
  final List<dynamic> continueWatching;
  final List<dynamic> recentlyAdded;
  final List<dynamic> movies;
  final List<dynamic> series;
}
