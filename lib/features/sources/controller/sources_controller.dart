import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../capabilities/library/file_source.dart';
import '../../../capabilities/library/library_service.dart';
import '../../../capabilities/playback/playback_launcher.dart';
import '../../../capabilities/sources/source_manager.dart';
import '../../../core/capabilities/source_capability.dart';
import '../../../data/configuration/source_configuration_service.dart';
import '../../../data/sources/source_config.dart';
import '../model/sources_state.dart';

/// The Sources tab: connections with their file sources, switching and
/// deleting connections, and browsing one connection's files.
class SourcesController extends ChangeNotifier {
  SourcesController({required this.sources, this.library}) {
    _libraryChanges = library?.changes.listen((_) => _notify());
    _sourceChanges = sources.changes.listen((_) {
      final current = _state.browsing;
      if (current != null && !sources.sourceVisibleToAccount(current.id)) {
        _set(
          _state.copyWith(
            browsing: () => null,
            path: const [],
            entries: const [],
            nextOffset: () => null,
          ),
        );
      } else {
        _notify();
      }
    });
  }

  final SourceManager sources;

  /// File sources are listed beneath their connection when available.
  final LibraryService? library;

  SourcesState _state = const SourcesState();
  SourcesState get state => _state;
  StreamSubscription<void>? _libraryChanges;
  StreamSubscription<SourceChange>? _sourceChanges;
  bool _disposed = false;

  void _set(SourcesState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ---- Reading -------------------------------------------------------------

  List<SourceConfig> get connections => sources.configs;
  List<ConfigurationIssue> get issues => sources.configurationIssues;

  List<FileSource> fileSourcesOf(String connection) => [
    for (final f in library?.fileSourceList() ?? const <FileSource>[])
      if (f.connectionId == connection) f,
  ];

  /// File sources whose connection no longer exists; they stay removable.
  List<FileSource> get orphanFileSources {
    final known = {for (final c in sources.configs) c.id};
    return [
      for (final f in library?.fileSourceList() ?? const <FileSource>[])
        if (!known.contains(f.connectionId) &&
            sources.sourceVisibleToAccount(f.connectionId))
          f,
    ];
  }

  /// What switching off or deleting [connection] affects.
  SourceImpact impact(String connection) {
    final i = sources.impact(connection);
    return SourceImpact(
      fileSources: library?.fileSourcesOf(connection).length ?? 0,
      playing: i.playing,
      running: i.running,
    );
  }

  bool isExpanded(SourceConfig connection) =>
      _state.expanded[connection.id] ?? false;

  void setExpanded(String connection, bool expanded) => _set(
    _state.copyWith(expanded: {..._state.expanded, connection: expanded}),
  );

  // ---- Loading and browsing --------------------------------------------------

  /// Reloads the connections, or the current folder while browsing; [more]
  /// appends the folder's next page.
  Future<void> load({bool more = false}) async {
    _set(_state.copyWith(busy: true, failure: () => null));
    SourcesFailure? failure;
    BrowseResult? page;
    final browsing = _state.browsing;
    try {
      await sources.load();
      if (browsing == null && !more) await sources.reload();
      if (browsing != null) {
        page = await sources.browse(
          browsing.id,
          BrowseRequest(
            node: _state.path.lastOrNull?.ref,
            offset: more ? _state.nextOffset! : 0,
          ),
        );
      }
    } catch (error) {
      failure = SourcesFailure(
        SourcesFailureKind.load,
        error is PluginException ? error.message : null,
      );
    }
    if (_disposed) return;
    final result = page;
    _set(
      _state.copyWith(
        busy: false,
        failure: () => failure,
        entries: result == null
            ? null
            : [if (more) ..._state.entries, ...result.entries],
        nextOffset: result == null ? null : () => result.nextOffset,
      ),
    );
  }

  void browse(SourceConfig connection) {
    _set(
      _state.copyWith(browsing: () => connection, path: const [], entries: []),
    );
    unawaited(load());
  }

  /// Up one folder, or out of the connection.
  void back() {
    _set(
      _state.path.isNotEmpty
          ? _state.copyWith(
              path: [..._state.path]..removeLast(),
              entries: const [],
              nextOffset: () => null,
            )
          : _state.copyWith(
              browsing: () => null,
              entries: const [],
              nextOffset: () => null,
            ),
    );
    unawaited(load());
  }

  /// Opens [entry]: a folder is browsed into (null is returned), a file is
  /// prepared for playback. [wanted] says whether the page still wants it.
  Future<SourceSelection?> open(
    SourceEntry entry, {
    required bool Function() wanted,
  }) async {
    if (entry.isFolder) {
      _set(_state.copyWith(path: [..._state.path, entry]));
      await load();
      return null;
    }
    _set(_state.copyWith(busy: true, failure: () => null));
    try {
      final selection = await PlaybackLauncher(sources)
          .select(entry.ref, entry.name, entry: entry, wanted: wanted);
      _set(_state.copyWith(busy: false));
      return selection;
    } catch (error) {
      _set(
        _state.copyWith(
          busy: false,
          failure: () => SourcesFailure(
            SourcesFailureKind.play,
            error is PluginException ? error.message : null,
          ),
        ),
      );
      return null;
    }
  }

  // ---- Changing connections --------------------------------------------------

  /// Switches [connection] on or off; the library follows (its media show
  /// or hide).
  Future<void> setEnabled(String connection, bool enabled) async {
    _set(_state.copyWith(busy: true));
    try {
      await sources.setEnabled(connection, enabled);
    } catch (error) {
      _set(
        _state.copyWith(
          busy: false,
          failure: () => SourcesFailure(
            SourcesFailureKind.toggle,
            error is PluginException ? error.message : null,
          ),
        ),
      );
      return;
    }
    await load();
  }

  /// Deletes [connection]; the library drops its file sources and what only
  /// they brought in.
  Future<void> remove(String connection) async {
    _set(_state.copyWith(busy: true));
    try {
      await sources.remove(connection);
    } catch (_) {
      _set(
        _state.copyWith(
          busy: false,
          failure: () => const SourcesFailure(SourcesFailureKind.delete),
        ),
      );
      return;
    }
    await load();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_libraryChanges?.cancel());
    unawaited(_sourceChanges?.cancel());
    super.dispose();
  }
}
