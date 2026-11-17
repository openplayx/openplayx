import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../capabilities/library/library_service.dart';
import '../../../capabilities/sources/source_manager.dart';
import '../../../core/capabilities/source_capability.dart';

/// Why the last file source operation failed.
enum FileSourceFailure {
  /// A scan failed; what it had found is kept.
  scan,

  /// The folder could not be added.
  bind,
}

/// Adding, scanning, renaming and removing file sources: folders of a
/// connection that feed the library. Dialogs and pickers stay in the view.
class FileSourceController extends ChangeNotifier {
  FileSourceController(this.library, this.sources);
  final LibraryService library;
  final SourceManager sources;

  bool _scanning = false;
  bool get scanning => _scanning;
  FileSourceFailure? _failure;
  FileSourceFailure? get failure => _failure;
  Timer? _refresh;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Scans [ids] one after the other; a failing one keeps its own error
  /// and does not stop the others.
  Future<void> scan(List<String> ids) async {
    if (_scanning || ids.isEmpty) return;
    _scanning = true;
    _failure = null;
    _notify();
    // The found-so-far counter is read from the database, so poll for it.
    _refresh = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _notify();
    });
    try {
      for (final id in ids) {
        try {
          await library.scan(id, sources);
        } catch (_) {
          _failure = FileSourceFailure.scan;
        }
      }
    } finally {
      _refresh?.cancel();
      _scanning = false;
      _notify();
    }
  }

  /// Name proposed for a new file source of [connection] at [scope].
  String suggestedName(String connection, SourceEntry scope) {
    if (scope.ref.id.isNotEmpty) return scope.name;
    final config = sources.configs.where((c) => c.id == connection).firstOrNull;
    return config?.titleName ?? scope.name;
  }

  /// Adds [scope] of [connection] as a file source named [name] and scans
  /// it right away.
  Future<void> add(String connection, SourceEntry scope, String name) async {
    final String id;
    try {
      id = library.addFileSource(
        connection,
        root: scope.ref.id.isEmpty ? null : scope.ref.id,
        name: name,
        rootEntry: scope,
      );
    } catch (_) {
      _failure = FileSourceFailure.bind;
      _notify();
      return;
    }
    await scan([id]);
  }

  /// Media that only [id] brought into the library, removed with it.
  int impact(String id) => library.fileSourceImpact(id);

  void rename(String id, String name) => library.renameFileSource(id, name);
  void remove(String id) => library.removeFileSource(id);
  void setEnabled(String id, bool enabled) =>
      library.setFileSourceEnabled(id, enabled);

  @override
  void dispose() {
    _disposed = true;
    _refresh?.cancel();
    super.dispose();
  }
}
