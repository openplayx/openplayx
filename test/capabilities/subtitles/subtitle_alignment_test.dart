import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/subtitles/subtitle_alignment.dart';

String fixture({
  double scale = 1,
  int offset = 0,
  int count = 36,
  String prefix = 'Dialogue line number',
  bool reverseText = false,
  Set<int> corrupt = const {},
}) {
  final cues = [
    for (var i = 0; i < count; i++)
      SrtCue(
        (10000 + i * 10000).toDouble().round(),
        (11000 + i * 10000).toDouble().round(),
        '<i>$prefix ${reverseText ? count - i : i}</i>\nSecond line.',
        ' X1:10',
      ),
  ];
  final text = SrtDocument(cues)
      .export(AlignmentMapping(scale: scale, offsetMs: offset.toDouble()));
  if (corrupt.isEmpty) return text;
  final doc = SrtDocument.parse(text);
  return SrtDocument([
    for (var i = 0; i < doc.cues.length; i++)
      SrtCue(
        doc.cues[i].startMs + (corrupt.contains(i) ? 2000 : 0),
        doc.cues[i].endMs + (corrupt.contains(i) ? 2000 : 0),
        doc.cues[i].text,
        doc.cues[i].settings,
      ),
  ]).export(const AlignmentMapping());
}

void main() {
  test('fixed offset preserves multiline text and SRT settings', () {
    final r = alignReference(fixture(), fixture(offset: 2500), 500000);
    expect(r.safe, isTrue);
    expect(r.mapping.scale, 1);
    expect(r.mapping.offsetMs, 2500);
    expect(r.p95Ms, 0);
    final exported = SrtDocument.parse(r.source.export(r.mapping));
    expect(exported.cues.first.startMs, 12500);
    expect(
      exported.cues.first.text,
      '<i>Dialogue line number 0</i>\nSecond line.',
    );
    expect(exported.cues.first.settings, ' X1:10');
  });
  test('linear drift is fitted with independent held-out anchors', () {
    final r = alignReference(
      fixture(),
      fixture(scale: 25 / 23.976, offset: 1300),
      500000,
    );
    expect(r.safe, isTrue);
    expect(r.mapping.scale, closeTo(25 / 23.976, .00001));
    expect(r.p95Ms, lessThanOrEqualTo(2));
    expect(r.validation.length, 12);
    expect(r.anchors.length, 36);
  });
  test('already synchronized reference leaves timestamps unchanged', () {
    final r = alignReference(fixture(), fixture(), 500000);
    expect(r.safe, isTrue);
    expect(r.source.export(r.mapping), fixture());
  });
  test('held-out disagreement fails gate despite exact training fit', () {
    final r = alignReference(
      fixture(),
      fixture(corrupt: {0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33}),
      500000,
    );
    expect(r.safe, isFalse);
    expect(r.p95Ms, greaterThan(300));
  });
  test('wrong language or episode has insufficient evidence', () {
    expect(
      () => alignReference(
        fixture(),
        fixture(prefix: 'Different content'),
        500000,
      ),
      throwsFormatException,
    );
  });
  test('unknown duration never passes the boundary gate', () {
    expect(alignReference(fixture(), fixture(offset: 2500), 0).safe, isFalse);
  });
  test('out of video bounds fails without clamping or dropping cues', () {
    final r = alignReference(fixture(), fixture(offset: 2500), 300000);
    expect(r.safe, isFalse);
    expect(r.invalidCues, greaterThan(0));
    expect(r.source.cues.length, 36);
  });
  test('reordered matching dialogue is rejected', () {
    expect(
      alignReference(fixture(), fixture(reverseText: true), 500000).safe,
      isFalse,
    );
  });
  test('sparse anchors cannot establish full timeline evidence', () {
    final source = SrtDocument.parse(fixture());
    final ref = SrtDocument(source.cues.take(12).toList())
        .export(const AlignmentMapping(offsetMs: 2500));
    expect(alignReference(fixture(), ref, 500000).safe, isFalse);
  });
  test('SRT parser rejects malformed and reversed timelines', () {
    expect(() => SrtDocument.parse('not a subtitle'), throwsFormatException);
    expect(
      () => SrtDocument.parse('1\n00:00:02,000 --> 00:00:01,000\nhello'),
      throwsFormatException,
    );
    expect(
      () => SrtDocument.parse('1\n00:61:00,000 --> 00:62:00,000\nhello'),
      throwsFormatException,
    );
  });
  test('UTF-8 BOM and CRLF are accepted', () {
    expect(
      SrtDocument.parse('\uFEFF${fixture().replaceAll('\n', '\r\n')}')
          .cues
          .length,
      36,
    );
  });
}
