import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../capabilities/library/library_service.dart';
import '../../../capabilities/library/file_source.dart';
import '../model/home_shelves.dart';

/// The home shelves: queried outside build (the queries are synchronous and
/// cost tens of milliseconds, while build also runs on resize and theme
/// changes), refreshed on library changes once the page is visible, and
/// the shown items queued for metadata first.
class HomeController extends ChangeNotifier {
  HomeController(this.service) {
    _shelves = _load();
    _changes = service.changes.listen((_) => refresh());
  }

  static const shelfLimit = 20;

  final LibraryService service;
  late HomeShelves _shelves;
  HomeShelves get shelves => _shelves;
  List<({FileSource source, int count})> scanStates = [];
  StreamSubscription<void>? _changes;
  bool _visible = true;

  /// The library changed while the page was hidden (another tab, a pushed
  /// route); reloaded once it becomes visible again.
  bool _stale = false;
  bool _disposed = false;
  final _boosted = <String>{};
  final _boostPending = <String>[];

  /// Whether the page is on screen.
  void setVisible(bool visible) {
    _visible = visible;
    if (visible && _stale) refresh();
  }

  void refresh() {
    if (_disposed) return;
    if (!_visible) {
      _stale = true;
      return;
    }
    _stale = false;
    _shelves = _load();
    notifyListeners();
  }

  /// Reloads at once (the shell recreates the page when the home tab is
  /// selected again).
  void reload() {
    _stale = false;
    _shelves = _load();
  }

  /// Queues on-screen items for metadata once, flushed after the frame.
  void _boost(String id) {
    if (!_boosted.add(id)) return;
    if (_boostPending.isEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final ids = List<String>.of(_boostPending);
        _boostPending.clear();
        if (!_disposed) service.prioritizeMetadata(ids);
      });
    }
    _boostPending.add(id);
  }

  HomeShelves _load() {
    scanStates = [
      for (final source in service.fileSourceList().where((f) => f.enabled))
        (
          source: source,
          count: source.scanning
              ? service.scannedMediaCount(source.id)
              : service.fileSourceMediaCount(source.id),
        ),
    ];
    List<dynamic> posters(String? contentType) =>
        service.query(contentType: contentType, limit: shelfLimit);
    final shelves = HomeShelves(
      continueWatching: service.continueWatching(limit: 200),
      recentlyAdded: posters(null),
      movies: posters('movie'),
      series: posters('series'),
    );
    for (final rows in [
      shelves.recentlyAdded,
      shelves.movies,
      shelves.series,
    ]) {
      for (final row in rows) {
        _boost(row['id'] as String);
      }
    }
    return shelves;
  }

  /// Whether any file source exists (explains an empty home).
  bool get hasFileSources => service.fileSources().isNotEmpty;

  @override
  void dispose() {
    _disposed = true;
    unawaited(_changes?.cancel());
    super.dispose();
  }
}
