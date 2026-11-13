import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../../core/plugins/source_capability.dart';

/// A subtitle the user saved from speech recognition, bound to one resource
/// version. Read straight from the library database so any player (also the
/// separate desktop player window) can list it without the workflow service.
class RecognizedSubtitle {
  const RecognizedSubtitle({
    required this.bindingId,
    required this.path,
    required this.format,
    required this.language,
    required this.partial,
    required this.rangeStartMs,
    required this.rangeEndMs,
    required this.backend,
    required this.modelId,
    required this.created,
  });
  final String bindingId;

  /// Internal file path (handed to the player only).
  final String path;
  final String format;
  final String? language;

  /// True for a range (e.g. a 60 s debug run), never shown as complete.
  final bool partial;
  final int rangeStartMs, rangeEndMs;
  final String? backend;
  final String? modelId;
  final DateTime created;
}

/// Saved recognised subtitles of [ref], newest first; files that no longer
/// exist are skipped. Empty when the tables do not exist yet.
List<RecognizedSubtitle> recognizedSubtitles(Database db, ResourceRef ref) {
  try {
    return [
      for (final r in db.select(
        '''SELECT b.*, a.path FROM subtitle_bindings b
           JOIN media_artifacts a ON a.id = b.subtitle_artifact_id
           WHERE b.resource_source=? AND b.resource_item=?
           ORDER BY b.created DESC''',
        [ref.instanceId, ref.id],
      ))
        if (File(r['path'] as String).existsSync())
          RecognizedSubtitle(
            bindingId: r['id'] as String,
            path: r['path'] as String,
            format: r['format'] as String,
            language: r['language'] as String?,
            partial: r['partial'] == 1,
            rangeStartMs: r['range_start_ms'] as int,
            rangeEndMs: r['range_end_ms'] as int,
            backend: r['backend'] as String?,
            modelId: r['model_id'] as String?,
            created: DateTime.fromMillisecondsSinceEpoch(r['created'] as int),
          ),
    ];
  } on SqliteException {
    return const [];
  }
}
