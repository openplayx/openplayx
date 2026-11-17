import 'package:flutter/foundation.dart';

import '../../../capabilities/speech/recognized_subtitles.dart';

/// Where a subtitle comes from; the player lists the groups separately.
sealed class SubtitleSource {
  const SubtitleSource();
}

/// A track of the media itself.
class EmbeddedSubtitle extends SubtitleSource {
  const EmbeddedSubtitle();
}

/// A subtitle file the user loaded.
class ExternalSubtitle extends SubtitleSource {
  const ExternalSubtitle(this.file);
  final Uri file;
}

/// A saved speech-recognition result of the current resource.
class RecognizedSubtitleSource extends SubtitleSource {
  const RecognizedSubtitleSource(this.saved);
  final RecognizedSubtitle saved;
}

/// One subtitle the user can choose.
@immutable
class SubtitleOption {
  const SubtitleOption({
    required this.key,
    required this.source,
    required this.name,
    this.language,
    this.playerId,
    this.loading = false,
  });

  static String embeddedKey(int playerId) => 'embedded:$playerId';
  static String externalKey(Uri file) => 'file:$file';
  static String recognizedKey(String bindingId) => 'recognized:$bindingId';

  /// Stable identity within the current media; selections refer to it.
  final String key;
  final SubtitleSource source;
  final String name;
  final String? language;

  /// The player's track id once the subtitle is in the player; null for a
  /// recognised subtitle not loaded yet, or a file still loading.
  final int? playerId;

  /// Added to the player, which has not reported its track yet.
  final bool loading;
}

/// What the user chose.
sealed class SubtitleSelection {
  const SubtitleSelection();
}

/// Nothing chosen for this media: the player shows its default, which it
/// does not report, so no option is marked.
class SubtitleDefault extends SubtitleSelection {
  const SubtitleDefault();
}

class SubtitleOff extends SubtitleSelection {
  const SubtitleOff();
}

class SubtitleChosen extends SubtitleSelection {
  const SubtitleChosen(this.key);
  final String key;
}

/// Subtitle state of the current media; views render only this.
@immutable
class SubtitleState {
  const SubtitleState({
    this.options = const [],
    this.selection = const SubtitleDefault(),
    this.lastChosen,
    this.delay = Duration.zero,
  });

  /// Every choosable subtitle: embedded, then external, then recognised.
  final List<SubtitleOption> options;
  final SubtitleSelection selection;

  /// Key of the last option chosen in this media, for "subtitles on".
  final String? lastChosen;
  final Duration delay;

  List<SubtitleOption> _of<T extends SubtitleSource>() => [
    for (final o in options)
      if (o.source is T) o,
  ];

  List<SubtitleOption> get embedded => _of<EmbeddedSubtitle>();
  List<SubtitleOption> get external => _of<ExternalSubtitle>();
  List<SubtitleOption> get recognized => _of<RecognizedSubtitleSource>();

  SubtitleOption? option(String key) =>
      options.where((o) => o.key == key).firstOrNull;

  bool get isOff => selection is SubtitleOff;

  /// The chosen option, if one is chosen and still exists.
  SubtitleOption? get selected => switch (selection) {
    SubtitleChosen(:final key) => option(key),
    _ => null,
  };

  bool isSelected(SubtitleOption option) => selected?.key == option.key;

  /// Target of "next"/"previous subtitle" over off and every option. With
  /// nothing chosen yet, next is the first option and previous is off. Null
  /// without options.
  SubtitleSelection? cycleTarget(int direction) {
    if (options.isEmpty) return null;
    final slots = <SubtitleSelection>[
      const SubtitleOff(),
      for (final o in options) SubtitleChosen(o.key),
    ];
    final current = switch (selection) {
      SubtitleOff() => 0,
      SubtitleChosen(:final key) => options.indexWhere((o) => o.key == key) + 1,
      SubtitleDefault() => 0,
    };
    // The default (or a vanished choice) sits just before the first option.
    final before = selection is SubtitleDefault || (current == 0 && !isOff);
    final index = before
        ? (direction > 0 ? 1 : 0)
        : (current + direction) % slots.length;
    return slots[index];
  }

  /// Target of "subtitles on/off": off, or back from off to the last
  /// chosen option (else the first). Null when there is nothing to show.
  SubtitleSelection? get toggleTarget {
    if (!isOff) return const SubtitleOff();
    final last = lastChosen == null ? null : option(lastChosen!);
    final target = last ?? options.firstOrNull;
    return target == null ? null : SubtitleChosen(target.key);
  }

  SubtitleState copyWith({
    List<SubtitleOption>? options,
    SubtitleSelection? selection,
    String? lastChosen,
    Duration? delay,
  }) => SubtitleState(
    options: options ?? this.options,
    selection: selection ?? this.selection,
    lastChosen: lastChosen ?? this.lastChosen,
    delay: delay ?? this.delay,
  );
}
