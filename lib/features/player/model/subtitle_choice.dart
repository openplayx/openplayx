import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'subtitle_state.dart';

/// The subtitle the user last chose for a resource, kept across sessions
/// and applied again when the resource is played next time.
@immutable
sealed class SubtitleChoice {
  const SubtitleChoice();

  /// The choice for [option]: what identifies it again in a later session.
  factory SubtitleChoice.of(SubtitleOption option) => switch (option.source) {
    EmbeddedSubtitle() => EmbeddedChoice(
      playerId: option.playerId,
      name: option.name,
      language: option.language,
    ),
    ExternalSubtitle(:final file) => ExternalChoice(file),
    RecognizedSubtitleSource(:final saved) => RecognizedChoice(saved.bindingId),
  };

  Map<String, Object?> toJson();
  String encode() => jsonEncode(toJson());

  /// Null for text this version does not understand.
  static SubtitleChoice? decode(String text) {
    try {
      final json = jsonDecode(text) as Map<String, Object?>;
      return switch (json['kind']) {
        'off' => const OffChoice(),
        'embedded' => EmbeddedChoice(
          playerId: json['player_id'] as int?,
          name: json['name'] as String? ?? '',
          language: json['language'] as String?,
        ),
        'external' => ExternalChoice(Uri.parse(json['file'] as String)),
        'recognized' => RecognizedChoice(json['binding_id'] as String),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}

/// Subtitles switched off.
class OffChoice extends SubtitleChoice {
  const OffChoice();
  @override
  Map<String, Object?> toJson() => {'kind': 'off'};
}

/// A track of the media, found again by id and name, else by name and
/// language.
class EmbeddedChoice extends SubtitleChoice {
  const EmbeddedChoice({
    required this.playerId,
    required this.name,
    this.language,
  });
  final int? playerId;
  final String name;
  final String? language;

  /// The option of the current media this choice refers to, if any.
  SubtitleOption? match(List<SubtitleOption> embedded) {
    final exact = embedded.where(
      (o) => o.playerId == playerId && o.name == name,
    );
    if (exact.isNotEmpty) return exact.first;
    final similar = embedded
        .where((o) => o.name == name && o.language == language)
        .toList();
    return similar.length == 1 ? similar.single : null;
  }

  @override
  Map<String, Object?> toJson() => {
    'kind': 'embedded',
    'player_id': playerId,
    'name': name,
    'language': language,
  };
}

/// A subtitle file the user loaded; loaded again if it still exists.
class ExternalChoice extends SubtitleChoice {
  const ExternalChoice(this.file);
  final Uri file;
  @override
  Map<String, Object?> toJson() => {'kind': 'external', 'file': '$file'};
}

/// A saved recognised subtitle, by binding id.
class RecognizedChoice extends SubtitleChoice {
  const RecognizedChoice(this.bindingId);
  final String bindingId;
  @override
  Map<String, Object?> toJson() => {
    'kind': 'recognized',
    'binding_id': bindingId,
  };
}
