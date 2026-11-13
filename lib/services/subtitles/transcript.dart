import '../../core/plugins/speech_recognition_capability.dart';

/// One recognised segment on the original media timeline (integer ms).
class TranscriptSegment {
  const TranscriptSegment(this.startMs, this.endMs, this.text);
  factory TranscriptSegment.fromJson(Map<String, dynamic> j) =>
      TranscriptSegment(
        j['start_ms'] as int,
        j['end_ms'] as int,
        j['text'] as String,
      );
  final int startMs, endMs;
  final String text;
  Map<String, Object> toJson() => {
    'start_ms': startMs,
    'end_ms': endMs,
    'text': text,
  };
}

/// Normalised transcript (design §8), always in `media_ms`.
class Transcript {
  const Transcript({
    required this.resourceRef,
    required this.audioTrackRef,
    required this.rangeStartMs,
    required this.rangeEndMs,
    required this.language,
    required this.backend,
    required this.modelId,
    required this.modelRevision,
    required this.engineVersion,
    required this.segments,
    this.wholeMedia = false,
    this.timestampLevel = 'segment',
    this.parameters = const {},
  });

  factory Transcript.fromJson(Map<String, dynamic> j) => Transcript(
    resourceRef: j['resource_ref'] as String,
    audioTrackRef: j['audio_track_ref'] as String,
    rangeStartMs: j['range_start_ms'] as int,
    rangeEndMs: j['range_end_ms'] as int,
    wholeMedia: j['whole_media'] as bool? ?? false,
    language: j['language'] as String,
    backend: j['backend'] as String,
    modelId: j['model_id'] as String,
    modelRevision: j['model_revision'] as String? ?? '',
    engineVersion: j['engine_version'] as String? ?? '',
    timestampLevel: j['timestamp_level'] as String? ?? 'segment',
    parameters: (j['parameters'] as Map?)?.cast<String, Object?>() ?? const {},
    segments: [
      for (final s in j['segments'] as List)
        TranscriptSegment.fromJson(s as Map<String, dynamic>),
    ],
  );

  static const schemaVersion = 1;
  final String resourceRef;
  final String audioTrackRef;
  final int rangeStartMs, rangeEndMs;

  /// True only when the whole media was processed; a 60 s debug range is
  /// never presented as a complete transcript.
  final bool wholeMedia;
  final String language;
  final String backend;
  final String modelId;
  final String modelRevision;
  final String engineVersion;
  final String timestampLevel;

  /// Summary of the recognition options (window, overlap, preset revision).
  final Map<String, Object?> parameters;
  final List<TranscriptSegment> segments;

  Map<String, Object?> toJson() => {
    'schema_version': schemaVersion,
    'resource_ref': resourceRef,
    'audio_track_ref': audioTrackRef,
    'range_start_ms': rangeStartMs,
    'range_end_ms': rangeEndMs,
    'whole_media': wholeMedia,
    'timebase': 'media_ms',
    'language': language,
    'backend': backend,
    'model_id': modelId,
    'model_revision': modelRevision,
    'engine_version': engineVersion,
    'timestamp_level': timestampLevel,
    'parameters': parameters,
    'segments': [for (final s in segments) s.toJson()],
  };
}

/// Annotations whisper emits for non-speech (`[BLANK_AUDIO]`, `(music)`,
/// `[音乐]`, `*laughs*`). They are not dialogue and must not become cues.
final _annotation = RegExp(
  r'^\s*(\[[^\]]*\]|\([^)]*\)|（[^）]*）|【[^】]*】|\*[^*]*\*|♪+)\s*$',
);

/// Merges per-window output into one ordered list in audio-local time, then
/// validates it (design §5).
///
/// Windows are read with an overlap tail; a segment belongs to the window
/// whose owned span `[offset, offset + window_ms)` contains its start. That
/// keeps exactly one copy of speech in the overlap without dropping real
/// repeated lines, and never adds an offset twice (native times are already
/// absolute within the audio).
List<TranscriptSegment> mergeWindows(
  RawTranscript raw, {
  double maxNoSpeechProb = 0.8,
  int maxTextLength = 500,
}) {
  final out = <TranscriptSegment>[];
  final windows = [...raw.windows]
    ..sort((a, b) => a.offsetMs.compareTo(b.offsetMs));
  for (var i = 0; i < windows.length; i++) {
    final w = windows[i];
    final last = i == windows.length - 1;
    final ownedEnd = last ? 1 << 62 : w.offsetMs + raw.windowMs;
    for (final s in w.segments) {
      if (s.startMs < w.offsetMs || s.startMs >= ownedEnd) continue;
      final text = s.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isEmpty || _annotation.hasMatch(text)) continue;
      if (s.noSpeechProb > maxNoSpeechProb) continue;
      var start = s.startMs, end = s.endMs;
      if (start < 0 || end < start) continue;
      if (raw.audioMs > 0) {
        if (start >= raw.audioMs) continue;
        if (end > raw.audioMs) end = raw.audioMs;
      }
      // The same text straddling a boundary twice (window i tail and i+1
      // head) collapses into one; distinct times keep genuine repetitions.
      final prev = out.lastOrNull;
      if (prev != null && prev.text == text && start < prev.endMs) {
        out[out.length - 1] = TranscriptSegment(
          prev.startMs,
          end > prev.endMs ? end : prev.endMs,
          text,
        );
        continue;
      }
      if (prev != null && start < prev.endMs) {
        // Overlapping neighbours: keep order, clip the earlier one.
        if (start <= prev.startMs) start = prev.endMs;
        if (start < prev.endMs) {
          out[out.length - 1] = TranscriptSegment(
            prev.startMs,
            start,
            prev.text,
          );
        }
        if (end < start) end = start;
      }
      out.add(
        TranscriptSegment(
          start,
          end,
          text.length > maxTextLength ? text.substring(0, maxTextLength) : text,
        ),
      );
    }
  }
  return out;
}

/// Maps audio-local segments onto the media timeline: media time = range
/// start + audio time. Extraction starts at `rangeStartMs` of the media, so
/// the offset is applied exactly once here.
List<TranscriptSegment> toMediaTime(
  List<TranscriptSegment> audio,
  int rangeStartMs, {
  int? rangeEndMs,
}) => [
  for (final s in audio)
    if (rangeEndMs == null || rangeStartMs + s.startMs < rangeEndMs)
      TranscriptSegment(
        rangeStartMs + s.startMs,
        rangeEndMs == null
            ? rangeStartMs + s.endMs
            : (rangeStartMs + s.endMs).clamp(0, rangeEndMs),
        s.text,
      ),
];

/// Throws [FormatException] for anything that would produce an invalid
/// subtitle (order, ranges, empty text).
void validateSegments(
  List<TranscriptSegment> segments, {
  int? minMs,
  int? maxMs,
}) {
  var prevStart = -1;
  for (final s in segments) {
    if (s.startMs < 0 || s.endMs < s.startMs) {
      throw const FormatException('segment_range');
    }
    if (s.startMs < prevStart) throw const FormatException('segment_order');
    if (minMs != null && s.startMs < minMs) {
      throw const FormatException('segment_before_range');
    }
    if (maxMs != null && s.endMs > maxMs) {
      throw const FormatException('segment_after_range');
    }
    if (s.text.trim().isEmpty) throw const FormatException('segment_empty');
    prevStart = s.startMs;
  }
}
