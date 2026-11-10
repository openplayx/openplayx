import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/sources/source_config.dart';

void main() {
  test('parses mixed separators and leading dots', () {
    expect(parseScanExtensions('mp4, .MKV；*.avi  mp4'), ['mp4', 'mkv', 'avi']);
  });
  test('matches by case-insensitive suffix; empty keeps everything', () {
    expect(matchesScanExtension('a.MKV', ['mkv']), isTrue);
    expect(matchesScanExtension('a.srt', ['mkv']), isFalse);
    expect(matchesScanExtension('noext', ['mkv']), isFalse);
    expect(matchesScanExtension('a.srt', const []), isTrue);
  });
  test('always drops dot-prefixed hidden files', () {
    expect(matchesScanExtension('._movie.mp4', ['mp4']), isFalse);
    expect(matchesScanExtension('.DS_Store', const []), isFalse);
    expect(matchesScanExtension('.hidden.mkv', const []), isFalse);
  });
}
