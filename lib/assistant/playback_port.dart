import 'dart:async';

import '../capabilities/sources/source_manager.dart';

/// How the assistant reaches the player. The App implements it over the
/// embedded player or the player windows; the assistant never touches
/// player widgets.
abstract interface class PlaybackPort {
  /// Playback state as the assistant sees it; with [waitForSession], waits
  /// briefly until a just-opened media has a session.
  FutureOr<Map<String, dynamic>> snapshot({bool waitForSession = false});

  /// Runs a playback command for `args['session_id']`; throws a
  /// [StateError] whose message is a short reason code.
  Future<Map<String, dynamic>> control(
    String command,
    Map<String, dynamic> args,
  );

  /// Whether the player can open something now (not opening or closing).
  bool get ready;

  /// Shows [selection] in the player.
  Future<void> play(SourceSelection selection);
}
