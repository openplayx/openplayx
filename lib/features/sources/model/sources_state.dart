import 'package:flutter/foundation.dart';

import '../../../core/capabilities/source_capability.dart';
import '../../../data/sources/source_config.dart';

enum SourcesFailureKind { load, play, toggle, delete }

/// Why the last operation of the Sources tab failed; [message] is the
/// source's own explanation when it gave one.
@immutable
class SourcesFailure {
  const SourcesFailure(this.kind, [this.message]);
  final SourcesFailureKind kind;
  final String? message;
}

/// What switching off or deleting a connection affects.
@immutable
class SourceImpact {
  const SourceImpact({
    this.fileSources = 0,
    this.playing = 0,
    this.running = 0,
  });

  /// File sources of the connection (deleted with it).
  final int fileSources;
  final int playing;
  final int running;

  bool get interruptsWork => playing > 0 || running > 0;
}

/// State of the Sources tab. The connections and file sources themselves
/// are read from the capabilities; this holds what the tab adds.
@immutable
class SourcesState {
  const SourcesState({
    this.busy = true,
    this.failure,
    this.expanded = const {},
    this.browsing,
    this.path = const [],
    this.entries = const [],
    this.nextOffset,
  });

  final bool busy;
  final SourcesFailure? failure;

  /// Connection id → expanded; unset connections are collapsed.
  final Map<String, bool> expanded;

  /// The connection whose files are browsed, if any.
  final SourceConfig? browsing;

  /// Folders opened within [browsing].
  final List<SourceEntry> path;
  final List<SourceEntry> entries;

  /// Offset of the next page of [entries], if there is one.
  final int? nextOffset;

  SourcesState copyWith({
    bool? busy,
    SourcesFailure? Function()? failure,
    Map<String, bool>? expanded,
    SourceConfig? Function()? browsing,
    List<SourceEntry>? path,
    List<SourceEntry>? entries,
    int? Function()? nextOffset,
  }) => SourcesState(
    busy: busy ?? this.busy,
    failure: failure == null ? this.failure : failure(),
    expanded: expanded ?? this.expanded,
    browsing: browsing == null ? this.browsing : browsing(),
    path: path ?? this.path,
    entries: entries ?? this.entries,
    nextOffset: nextOffset == null ? this.nextOffset : nextOffset(),
  );
}
