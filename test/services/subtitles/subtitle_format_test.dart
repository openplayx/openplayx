import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/speech_recognition_capability.dart';
import 'package:openplayx/services/subtitles/subtitle_format.dart';
import 'package:openplayx/services/subtitles/transcript.dart';
import 'package:openplayx_whisper/openplayx_whisper.dart';

RawTranscript raw(List<RawWindow> windows, {int audioMs = 90000}) =>
    RawTranscript(
      language: 'en',
      audioMs: audioMs,
      windowMs: 30000,
      overlapMs: 1000,
      windows: windows,
    );

void main() {
  group('mergeWindows', () {
    test('keeps one copy of speech recognised in the overlap', () {
      final merged = mergeWindows(
        raw([
          const RawWindow(0, 31000, [
            RawSegment(28000, 30800, 'Crossing the boundary.'),
          ]),
          const RawWindow(30000, 31000, [
            // Same speech, seen again from the next window's start.
            RawSegment(30000, 30800, 'Crossing the boundary.'),
            RawSegment(32000, 34000, 'Next line.'),
          ]),
        ]),
      );
      expect(merged.map((s) => s.text), [
        'Crossing the boundary.',
        'Next line.',
      ]);
      expect(merged.first.startMs, 28000);
    });

    test('segments starting in the overlap belong to the next window', () {
      final merged = mergeWindows(
        raw([
          const RawWindow(0, 31000, [RawSegment(30200, 31000, 'Tail')]),
          const RawWindow(30000, 31000, [
            RawSegment(30200, 31500, 'Tail line'),
          ]),
        ]),
      );
      expect(merged.single.text, 'Tail line');
    });

    test('real repetitions at different times are kept', () {
      final merged = mergeWindows(
        raw([
          const RawWindow(0, 31000, [
            RawSegment(1000, 2000, 'No!'),
            RawSegment(2500, 3500, 'No!'),
          ]),
        ]),
      );
      expect(merged, hasLength(2));
    });

    test('drops annotations, empty text and likely non-speech', () {
      final merged = mergeWindows(
        raw([
          const RawWindow(0, 31000, [
            RawSegment(0, 1000, ' [BLANK_AUDIO] '),
            RawSegment(1000, 2000, '(音乐)'),
            RawSegment(2000, 3000, '   '),
            RawSegment(3000, 4000, 'Hallucination', 0.95),
            RawSegment(4000, 5000, ' Real  words '),
          ]),
        ]),
      );
      expect(merged.single.text, 'Real words');
    });

    test('clips segments past the audio end and rejects inverted ones', () {
      final merged = mergeWindows(
        raw([
          const RawWindow(0, 10000, [
            RawSegment(5000, 4000, 'bad'),
            RawSegment(8000, 12000, 'clipped'),
            RawSegment(11000, 12000, 'outside'),
          ]),
        ], audioMs: 10000),
      );
      expect(merged.single.endMs, 10000);
    });
  });

  test('media time adds the range start exactly once', () {
    final media = toMediaTime(
      const [TranscriptSegment(1200, 4800, 'x')],
      600000,
      rangeEndMs: 660000,
    );
    expect(media.single.startMs, 601200);
    expect(media.single.endMs, 604800);
    validateSegments(media, minMs: 600000, maxMs: 660000);
  });

  test('validation rejects disorder and out-of-range segments', () {
    expect(
      () => validateSegments(const [
        TranscriptSegment(2000, 3000, 'b'),
        TranscriptSegment(1000, 1500, 'a'),
      ]),
      throwsFormatException,
    );
    expect(
      () =>
          validateSegments(const [TranscriptSegment(0, 500, 'a')], minMs: 1000),
      throwsFormatException,
    );
  });

  group('cues', () {
    test('long Chinese text without spaces is split by punctuation/width', () {
      final text = '今天天气很好，我们一起去公园散步吧。' * 4;
      final cues = buildCues([TranscriptSegment(0, 16000, text)]);
      expect(cues.length, greaterThan(1));
      for (final c in cues) {
        expect(displayWidth(c.text), lessThanOrEqualTo(84));
        expect(c.startMs, greaterThanOrEqualTo(0));
        expect(c.endMs, lessThanOrEqualTo(16000));
      }
      expect(cues.first.startMs, 0);
      expect(cues.last.endMs, 16000);
      expect(cues.map((c) => c.text).join(), text);
    });

    test('short segments keep their own times', () {
      final cues = buildCues(const [TranscriptSegment(1000, 2500, 'Hello.')]);
      expect(cues.single.startMs, 1000);
      expect(cues.single.endMs, 2500);
    });
  });

  test('SRT and VTT serialisation', () {
    const cues = [
      SubtitleCue(601200, 604800, 'Line one'),
      SubtitleCue(3723004, 3724000, 'a --> b'),
    ];
    expect(
      toSrt(cues),
      '1\n00:10:01,200 --> 00:10:04,800\nLine one\n\n'
      '2\n01:02:03,004 --> 01:02:04,000\na --> b\n\n',
    );
    final vtt = toVtt(cues, note: 'partial');
    expect(
      vtt,
      startsWith('WEBVTT\n\nNOTE partial\n\n00:10:01.200 --> 00:10:04.800\n'),
    );
    expect(vtt, contains('a → b'));
    expect(() => toSrt(const [SubtitleCue(5, 1, 'x')]), throwsFormatException);
  });

  test('cancel token runs listeners once', () {
    final t = AsrCancelToken();
    var n = 0;
    t.onCancel(() => n++);
    t.cancel();
    t.cancel();
    t.onCancel(() => n++);
    expect(n, 2);
  });
}
