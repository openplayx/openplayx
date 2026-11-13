import 'transcript.dart';

/// A displayable subtitle cue on the media timeline.
class SubtitleCue {
  const SubtitleCue(this.startMs, this.endMs, this.text);
  final int startMs, endMs;
  final String text;
}

enum SubtitleFormat {
  srt('srt', 'application/x-subrip'),
  vtt('vtt', 'text/vtt');

  const SubtitleFormat(this.extension, this.mime);
  final String extension;
  final String mime;
}

bool _isCjk(int rune) =>
    (rune >= 0x3040 && rune <= 0x30ff) ||
    (rune >= 0x3400 && rune <= 0x9fff) ||
    (rune >= 0xac00 && rune <= 0xd7af) ||
    (rune >= 0xf900 && rune <= 0xfaff);

/// Display width: CJK counts double, so 42 ≈ one line of Latin or 21 CJK.
int displayWidth(String text) =>
    text.runes.fold(0, (n, r) => n + (_isCjk(r) ? 2 : 1));

final _sentenceEnd = RegExp(r'(?<=[。！？!?；;…]|[.](?=\s))\s*');
final _clauseEnd = RegExp(r'(?<=[，,、：:])\s*');

/// Splits long segments into cues at punctuation (design §5.2).
///
/// Without word-level evidence the times of the pieces are proportional to
/// their display width inside the segment; this is an approximation that is
/// kept inside the segment bounds and never presented as aligned timing.
/// Text without punctuation (common for Chinese) is cut at the width limit;
/// spaces are not assumed to separate Chinese words.
List<SubtitleCue> buildCues(
  List<TranscriptSegment> segments, {
  int maxWidth = 84,
  int minCueMs = 700,
}) {
  final cues = <SubtitleCue>[];
  for (final s in segments) {
    final text = s.text.trim();
    if (text.isEmpty) continue;
    final duration = s.endMs - s.startMs;
    if (displayWidth(text) <= maxWidth || duration < minCueMs * 2) {
      cues.add(SubtitleCue(s.startMs, s.endMs, text));
      continue;
    }
    final pieces = <String>[];
    for (final sentence in text.split(_sentenceEnd)) {
      if (sentence.trim().isEmpty) continue;
      if (displayWidth(sentence) <= maxWidth) {
        pieces.add(sentence.trim());
        continue;
      }
      var current = '';
      for (final clause in sentence.split(_clauseEnd)) {
        if (clause.isEmpty) continue;
        if (current.isNotEmpty && displayWidth(current + clause) > maxWidth) {
          pieces.add(current.trim());
          current = '';
        }
        current += clause;
        while (displayWidth(current) > maxWidth) {
          final cut = _cutAt(current, maxWidth);
          pieces.add(current.substring(0, cut).trim());
          current = current.substring(cut);
        }
      }
      if (current.trim().isNotEmpty) pieces.add(current.trim());
    }
    // Merge pieces that would be shorter than minCueMs into their neighbour.
    final total = pieces.fold<int>(0, (n, p) => n + displayWidth(p));
    var at = s.startMs;
    var consumed = 0;
    var pending = '';
    for (var i = 0; i < pieces.length; i++) {
      pending = pending.isEmpty ? pieces[i] : _join(pending, pieces[i]);
      consumed += displayWidth(pieces[i]);
      final last = i == pieces.length - 1;
      final end = last ? s.endMs : s.startMs + duration * consumed ~/ total;
      if (!last && end - at < minCueMs) continue;
      cues.add(SubtitleCue(at, end, pending));
      at = end;
      pending = '';
    }
  }
  return cues;
}

String _join(String a, String b) {
  final ra = a.runes.last, rb = b.runes.first;
  return _isCjk(ra) || _isCjk(rb) ? '$a$b' : '$a $b';
}

/// Character index where the width limit is reached, preferring a space for
/// Latin text.
int _cutAt(String text, int maxWidth) {
  var width = 0;
  var index = 0;
  var lastSpace = -1;
  for (final r in text.runes) {
    final w = _isCjk(r) ? 2 : 1;
    if (width + w > maxWidth) break;
    width += w;
    index += String.fromCharCode(r).length;
    if (r == 0x20) lastSpace = index;
  }
  return lastSpace > index ~/ 2 ? lastSpace : (index == 0 ? 1 : index);
}

String _clock(int ms, String sep) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = ms ~/ 3600000, m = ms ~/ 60000 % 60, s = ms ~/ 1000 % 60;
  return '${two(h)}:${two(m)}:${two(s)}$sep${(ms % 1000).toString().padLeft(3, '0')}';
}

/// Checks the cue invariants every serialiser relies on.
void validateCues(List<SubtitleCue> cues) {
  var prev = -1;
  for (final c in cues) {
    if (c.startMs < 0 || c.endMs <= c.startMs) {
      throw const FormatException('cue_range');
    }
    if (c.startMs < prev) throw const FormatException('cue_order');
    if (c.text.trim().isEmpty) throw const FormatException('cue_empty');
    prev = c.startMs;
  }
}

/// Zero-length segments (rare, from very short words) get a minimum length
/// before serialisation so players do not drop them.
List<SubtitleCue> _displayable(List<SubtitleCue> cues) => [
  for (var i = 0; i < cues.length; i++)
    if (cues[i].endMs != cues[i].startMs)
      cues[i]
    else
      SubtitleCue(
        cues[i].startMs,
        i + 1 < cues.length && cues[i + 1].startMs > cues[i].startMs
            ? (cues[i].startMs + 500).clamp(0, cues[i + 1].startMs)
            : cues[i].startMs + 500,
        cues[i].text,
      ),
];

String _cueText(String text) =>
    text.replaceAll('\r', '').replaceAll(RegExp(r'\n{2,}'), '\n').trim();

String toSrt(List<SubtitleCue> cues) {
  final list = _displayable(cues);
  validateCues(list);
  final b = StringBuffer();
  for (var i = 0; i < list.length; i++) {
    final c = list[i];
    b
      ..write('${i + 1}\n')
      ..write('${_clock(c.startMs, ',')} --> ${_clock(c.endMs, ',')}\n')
      ..write('${_cueText(c.text)}\n\n');
  }
  return b.toString();
}

String toVtt(List<SubtitleCue> cues, {String? note}) {
  final list = _displayable(cues);
  validateCues(list);
  final b = StringBuffer('WEBVTT\n\n');
  if (note != null) b.write('NOTE ${note.replaceAll('-->', '→')}\n\n');
  for (final c in list) {
    // "-->" inside text would break VTT parsing.
    b
      ..write('${_clock(c.startMs, '.')} --> ${_clock(c.endMs, '.')}\n')
      ..write('${_cueText(c.text).replaceAll('-->', '→')}\n\n');
  }
  return b.toString();
}

String serialize(
  List<SubtitleCue> cues,
  SubtitleFormat format, {
  String? note,
}) => switch (format) {
  SubtitleFormat.srt => toSrt(cues),
  SubtitleFormat.vtt => toVtt(cues, note: note),
};
