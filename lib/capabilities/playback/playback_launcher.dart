import 'dart:io';

import '../../core/capabilities/source_capability.dart';
import '../sources/source_manager.dart';

/// A local file to play is gone.
class MediaUnavailable implements Exception {
  const MediaUnavailable(this.ref);
  final ResourceRef ref;
  @override
  String toString() => 'MediaUnavailable(${ref.id})';
}

/// The one way to turn a resource into something the player can open: a
/// file opened directly (`@local`) is checked and played as is, anything
/// else is resolved by its source. Home shelves, the detail page, the
/// sources browser, continue watching and the assistant all use it.
class PlaybackLauncher {
  const PlaybackLauncher(this.sources);
  final SourceManager sources;

  /// Opens a playable stream for [ref]. Throws [MediaUnavailable] for a
  /// missing local file, or what the source throws.
  Future<PlayableStream> open(ResourceRef ref) async {
    if (ref.instanceId == '@local') {
      if (!await File(ref.id).exists()) throw MediaUnavailable(ref);
      return PlayableStream(Uri.file(ref.id));
    }
    return sources.resolve(ref);
  }

  /// A selection for the player, or null when [wanted] says the caller no
  /// longer wants it once the stream is open (the stream is released then).
  Future<SourceSelection?> select(
    ResourceRef ref,
    String name, {
    SourceEntry? entry,
    bool Function()? wanted,
  }) async {
    final stream = await open(ref);
    if (wanted != null && !wanted()) {
      await stream.release();
      return null;
    }
    return SourceSelection(name, stream, ref: ref, entry: entry);
  }
}
