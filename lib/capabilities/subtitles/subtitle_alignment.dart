import 'dart:math' as math;

/// Conservative, bounded SRT reference alignment. A reference must already
/// follow the video's timeline and use the same dialogue language.
class SrtCue {
  const SrtCue(this.startMs, this.endMs, this.text, this.settings);
  final int startMs, endMs;
  final String text, settings;
}

class SrtDocument {
  const SrtDocument(this.cues);
  final List<SrtCue> cues;

  static SrtDocument parse(String input) {
    final text = input
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (text.isEmpty) throw const FormatException('empty');
    final cues = <SrtCue>[];
    final pattern = RegExp(
      r'^(\d{2,}):(\d{2}):(\d{2})[,\.](\d{3}) --> (\d{2,}):(\d{2}):(\d{2})[,\.](\d{3})(.*)$',
    );
    for (final block in text.split(RegExp(r'\n[ \t]*\n'))) {
      final lines = block.split('\n');
      if (lines.length < 3 || int.tryParse(lines.first.trim()) == null) {
        throw const FormatException('invalid_srt');
      }
      final m = pattern.firstMatch(lines[1].trim());
      if (m == null) throw const FormatException('invalid_srt');
      int time(int i) {
        final h = int.parse(m[i]!);
        final minutes = int.parse(m[i + 1]!);
        final seconds = int.parse(m[i + 2]!);
        if (minutes > 59 || seconds > 59) {
          throw const FormatException('invalid_time');
        }
        return ((h * 60 + minutes) * 60 + seconds) * 1000 +
            int.parse(m[i + 3]!);
      }

      final start = time(1), end = time(5);
      if (end <= start || (cues.isNotEmpty && start < cues.last.startMs)) {
        throw const FormatException('invalid_timeline');
      }
      cues.add(SrtCue(start, end, lines.skip(2).join('\n'), m[9]!));
      if (cues.length > 12000) throw const FormatException('too_many_cues');
    }
    return SrtDocument(List.unmodifiable(cues));
  }

  String export(AlignmentMapping mapping) {
    String stamp(int t) {
      final h = t ~/ 3600000,
          min = t ~/ 60000 % 60,
          s = t ~/ 1000 % 60,
          ms = t % 1000;
      return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')},${ms.toString().padLeft(3, '0')}';
    }

    return [
      for (var i = 0; i < cues.length; i++)
        '${i + 1}\n${stamp(mapping.map(cues[i].startMs))} --> ${stamp(mapping.map(cues[i].endMs))}${cues[i].settings}\n${cues[i].text}\n',
    ].join('\n');
  }
}

class AlignmentMapping {
  const AlignmentMapping({this.scale = 1, this.offsetMs = 0});
  final double scale, offsetMs;
  int map(int timeMs) => (timeMs * scale + offsetMs).round();
}

class AlignmentAnchor {
  const AlignmentAnchor(this.sourceMs, this.targetMs);
  final int sourceMs, targetMs;
}

class AlignmentResult {
  const AlignmentResult({
    required this.source,
    required this.mapping,
    required this.anchors,
    required this.validation,
    required this.p95Ms,
    required this.matchCoverage,
    required this.spanCoverage,
    required this.safe,
    required this.invalidCues,
  });
  final SrtDocument source;
  final AlignmentMapping mapping;
  final List<AlignmentAnchor> anchors, validation;
  final double p95Ms, matchCoverage, spanCoverage;
  final bool safe;
  final int invalidCues;
}

String _key(String text) => text
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
double _median(List<double> v) {
  v.sort();
  return v[v.length ~/ 2];
}

double _error(AlignmentMapping m, AlignmentAnchor a) =>
    (m.map(a.sourceMs) - a.targetMs).abs().toDouble();

/// Fits only training anchors. Every third anchor is held out for validation.
/// No VAD score is treated as a probability; unsupported cases require review.
AlignmentResult alignReference(
  String sourceText,
  String referenceText,
  int durationMs,
) {
  final source = SrtDocument.parse(sourceText),
      reference = SrtDocument.parse(referenceText);
  Map<String, List<SrtCue>> index(SrtDocument doc) {
    final result = <String, List<SrtCue>>{};
    for (final c in doc.cues) {
      final k = _key(c.text);
      if (k.length >= 6) (result[k] ??= []).add(c);
    }
    return result;
  }

  final a = index(source), b = index(reference);
  final all = <AlignmentAnchor>[];
  for (final entry in a.entries) {
    final other = b[entry.key];
    if (entry.value.length == 1 && other?.length == 1) {
      all.add(
        AlignmentAnchor(entry.value.single.startMs, other!.single.startMs),
      );
    }
  }
  all.sort((a, b) => a.sourceMs.compareTo(b.sourceMs));
  if (all.length < 12) throw const FormatException('insufficient_evidence');
  // Bounded sample distributed over the whole resource.
  final anchors = [
    for (var i = 0; i < math.min(all.length, 180); i++)
      all[(i * (all.length - 1) / (math.min(all.length, 180) - 1)).round()],
  ];
  final train = <AlignmentAnchor>[], validation = <AlignmentAnchor>[];
  for (var i = 0; i < anchors.length; i++) {
    (i % 3 == 0 ? validation : train).add(anchors[i]);
  }
  final offset = AlignmentMapping(
    offsetMs: _median([
      for (final p in train) (p.targetMs - p.sourceMs).toDouble(),
    ]),
  );
  final slopes = <double>[];
  for (var i = 0; i < train.length; i++) {
    for (var j = i + 1; j < train.length; j++) {
      final dx = train[j].sourceMs - train[i].sourceMs;
      if (dx >= 10000) slopes.add((train[j].targetMs - train[i].targetMs) / dx);
    }
  }
  var mapping = offset;
  if (slopes.isNotEmpty) {
    final scale = _median(slopes);
    final linear = AlignmentMapping(
      scale: scale,
      offsetMs: _median([
        for (final p in train) p.targetMs - scale * p.sourceMs,
      ]),
    );
    final offsetError = _median([for (final p in train) _error(offset, p)]),
        linearError = _median([for (final p in train) _error(linear, p)]);
    if (scale >= .9 && scale <= 1.1 && offsetError - linearError > 80) {
      mapping = linear;
    }
  }
  final errors = [for (final p in validation) _error(mapping, p)]..sort();
  final p95 = errors[((errors.length - 1) * .95).ceil()];
  final sourceSpan = source.cues.last.endMs - source.cues.first.startMs;
  final span = sourceSpan > 0
      ? (anchors.last.sourceMs - anchors.first.sourceMs) / sourceSpan
      : 0.0;
  final coverage = all.length / source.cues.length;
  var invalid = 0;
  var previous = -1;
  for (final cue in source.cues) {
    final start = mapping.map(cue.startMs), end = mapping.map(cue.endMs);
    if (start < 0 ||
        start < previous ||
        end <= start ||
        (durationMs > 0 && end > durationMs)) {
      invalid++;
    }
    previous = start;
  }
  final ordered = anchors.indexed.every(
    (e) => e.$1 == 0 || e.$2.targetMs > anchors[e.$1 - 1].targetMs,
  );
  final baseline = [
    for (final p in validation) _error(const AlignmentMapping(), p),
  ]..sort();
  return AlignmentResult(
    source: source,
    mapping: mapping,
    anchors: List.unmodifiable(anchors),
    validation: List.unmodifiable(validation),
    p95Ms: p95,
    matchCoverage: coverage,
    spanCoverage: span,
    invalidCues: invalid,
    safe:
        ordered &&
        durationMs > 0 &&
        invalid == 0 &&
        p95 <= 300 &&
        p95 <= baseline[((baseline.length - 1) * .95).ceil()] &&
        coverage >= .25 &&
        span >= .7,
  );
}
