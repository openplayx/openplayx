import 'package:flutter/foundation.dart';

import '../../../core/capabilities/source_capability.dart';

/// The library record of what is playing now.
@immutable
class PlaybackSession {
  const PlaybackSession({this.ref, this.resourceId, this.sessionId});

  /// Source resource being played; set as soon as tracking starts.
  final ResourceRef? ref;

  /// Library resource (version) id, once registered.
  final String? resourceId;

  /// Watch session id; progress is saved under it.
  final String? sessionId;

  PlaybackSession copyWith({String? resourceId, String? sessionId}) =>
      PlaybackSession(
        ref: ref,
        resourceId: resourceId ?? this.resourceId,
        sessionId: sessionId ?? this.sessionId,
      );

  /// The same resource without library ids, after saving failed.
  PlaybackSession detached() => PlaybackSession(ref: ref);
}
