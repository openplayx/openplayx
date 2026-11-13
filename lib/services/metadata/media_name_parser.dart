import '../../core/plugins/metadata_capability.dart';

class MediaNameEvidence {
  const MediaNameEvidence({
    required this.original,
    required this.title,
    required this.kind,
    this.year,
    this.season,
    this.episodes = const [],
    this.tags = const [],
    this.evidence = const [],
  });
  final String original;
  final String title;
  final MediaKind kind;
  final int? year;
  final int? season;
  final List<int> episodes;
  final List<String> tags;
  final List<String> evidence;
  static const ruleVersion = '2';
}

class MediaNameParser {
  const MediaNameParser();
  MediaNameEvidence parse(String name, {String? parent, MediaKind? kind}) {
    var text = name.replaceFirst(
      RegExp(r'\.[a-z0-9]{2,5}$', caseSensitive: false),
      '',
    );
    final tags = <String>[];
    final evidence = <String>[];
    int? year, season;
    final episodes = <int>[];
    final episode = RegExp(
      r'\bS(\d{1,2})((?:E\d{1,3})+)',
      caseSensitive: false,
    ).firstMatch(text.replaceAll(RegExp(r'[._]'), ' '));
    var cut = text.length;
    if (episode != null) {
      season = int.parse(episode[1]!);
      episodes.addAll(
        RegExp(
          r'E(\d+)',
          caseSensitive: false,
        ).allMatches(episode[2]!).map((m) => int.parse(m[1]!)),
      );
      cut = episode.start;
      evidence.add(episode[0]!);
      kind = MediaKind.episode;
    }
    final chinese = RegExp(r'第\s*(\d+)\s*季(?:\s*第?\s*(\d+)\s*集)?')
        .firstMatch(text);
    if (chinese != null) {
      season = int.parse(chinese[1]!);
      if (chinese[2] != null) episodes.add(int.parse(chinese[2]!));
      cut = cut < chinese.start ? cut : chinese.start;
      kind = episodes.isEmpty ? MediaKind.season : MediaKind.episode;
      evidence.add(chinese[0]!);
    }
    if (season == null && parent != null) {
      final match = RegExp(
        r'^(?:Season\s*|S)(\d{1,2})$',
        caseSensitive: false,
      ).firstMatch(parent);
      if (match != null) {
        season = int.parse(match[1]!);
        evidence.add(parent);
      }
    }
    final normalized = text.replaceAll(RegExp(r'[._]'), ' ');
    // Leading release-group/site tags ("[Group] Title", "【站点】Title") are not
    // part of the title; skip them when something follows.
    final lead = RegExp(r'^(?:\s*[\[【][^\]】]*[\]】])+\s*')
        .firstMatch(normalized);
    final start = lead != null && lead.end < normalized.length ? lead.end : 0;
    if (start > 0) evidence.add('leadingTag:${lead![0]!.trim()}');
    // A year must not be part of a resolution such as 1920x800.
    final years = RegExp(
      r'(?<!\d)(?<!\dx)(?:19|20)\d{2}(?!\d)(?!x\d)',
      caseSensitive: false,
    ).allMatches(normalized);
    final maxYear = DateTime.now().year + 1;
    // A numeric title such as 1917 is not itself evidence of a release year.
    for (final match in years) {
      if (match.start > start &&
          normalized.substring(start, match.start).trim().isNotEmpty &&
          int.parse(match[0]!) <= maxYear) {
        year = int.parse(match[0]!);
        cut = cut < match.start ? cut : match.start;
        evidence.add('year:$year');
        break;
      }
    }
    final technical = RegExp(
      r'\b(?:2160p|1080p|720p|480p|4K|BluRay|BDRip|WEB[ ._-]?DL|WEBRip|HDR10\+?|HDR|DV|x26[45]|H[ .]?26[45]|HEVC|AV1|REMUX|AAC|DTS|\d{3,4}x\d{3,4})\b',
      caseSensitive: false,
    );
    for (final match in technical.allMatches(normalized)) {
      if (match.start < start) continue;
      tags.add(match[0]!);
      cut = cut < match.start ? cut : match.start;
    }
    // "1997.Tomorrow.Never.Dies.1920x820": a leading year is the release year
    // only when no other year exists and title words follow before the tags.
    var titleStart = start;
    if (year == null) {
      final leading = RegExp(r'(?:19|20)\d{2}\s+')
          .matchAsPrefix(normalized, start);
      if (leading != null &&
          leading.end < cut &&
          normalized.substring(leading.end, cut).trim().isNotEmpty &&
          int.parse(leading[0]!.trim()) <= maxYear) {
        year = int.parse(leading[0]!.trim());
        titleStart = leading.end;
        evidence.add('year:$year');
      }
    }
    text = normalized
        .substring(titleStart < cut ? titleStart : 0, cut)
        .replaceAll(RegExp(r'^[\s\[\]()\-]+|[\s\[\]()\-]+$'), '')
        .trim();
    return MediaNameEvidence(
      original: name,
      title: text.isEmpty ? name : text,
      kind: kind ?? MediaKind.movie,
      year: year,
      season: season,
      episodes: episodes,
      tags: tags,
      evidence: evidence,
    );
  }
}
