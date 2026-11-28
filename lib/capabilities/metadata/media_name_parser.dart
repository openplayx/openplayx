import '../../core/capabilities/metadata_capability.dart';

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
    this.extra = false,
    this.episodeTitle,
  });
  final String original;
  final String title;
  final MediaKind kind;
  final int? year;
  final int? season;
  final List<int> episodes;
  final List<String> tags;
  final List<String> evidence;

  /// Bonus material of a series (featurettes, deleted scenes, "S01 Extra"
  /// files): [title] and [year] identify the series, not the clip itself.
  final bool extra;

  /// The episode's own title written after the episode marker
  /// ("Show - S04E24 - The One With Ross's Wedding (2) (1080p)"), when any.
  /// Release numbering can differ from the catalog's; the title can tell.
  final String? episodeTitle;
  static const ruleVersion = '3';
}

class MediaNameParser {
  const MediaNameParser();

  /// Folders that hold bonus material rather than the main titles.
  static final _extraFolder = RegExp(
    r'^(?:extras?|featurettes?|behind[ ._-]the[ ._-]scenes|deleted[ ._-]scenes|'
    r'interviews?|scenes|shorts|trailers?|samples?|bonus(?:[ ._-]features?)?|'
    r'bonus[ ._-]?disc|bloopers|other)$',
    caseSensitive: false,
  );

  /// Folders that only group a series' files ("Season 2", "S02", "Disc 1").
  static final _groupFolder = RegExp(
    r'^(?:(?:season|series|s)\s*\d{1,2}|specials|dis[ck]\s*\d+|cd\s*\d+)$',
    caseSensitive: false,
  );

  /// Bonus material named in the file itself.
  static final _extraName = RegExp(
    r'\b(?:deleted[ ._-]scenes?|bloopers|gag[ ._-]reel|featurette)\b|^sample[ ._-]|[ ._-]sample$',
    caseSensitive: false,
  );

  /// [path] is the file's full path in its source; its folders name the
  /// series when the file name alone does not (`Show/Season 1/S01E02.mkv`)
  /// and mark bonus material (`Show/Extras/Making Of.mkv`).
  MediaNameEvidence parse(
    String name, {
    String? parent,
    MediaKind? kind,
    String? path,
  }) {
    final folders = [...?path?.split('/').where((s) => s.isNotEmpty)];
    if (folders.isNotEmpty && folders.last == name) folders.removeLast();
    parent ??= folders.lastOrNull;
    var base = _parse(name, parent: parent, kind: kind);
    final collection = _collectionItem(name, folders);
    if (collection != null) {
      final item = _parse(collection.title, parent: parent, kind: kind);
      if (!item.untitled && item.marker == _Marker.none) {
        base = _Parsed(
          title: item.title,
          untitled: false,
          kind: item.kind,
          year: collection.year,
          season: item.season,
          episodes: item.episodes,
          tags: base.tags,
          evidence: [...base.evidence, 'collection:${collection.owner}'],
          marker: item.marker,
        );
      }
    }
    final extraFolder = folders.any((f) => _extraFolder.hasMatch(f.trim()));
    final extra =
        base.marker == _Marker.extra ||
        extraFolder ||
        _extraName.hasMatch(name.replaceFirst(RegExp(r'\.[a-z0-9]{2,5}$'), ''));
    // A series title is needed from the folders when the name has none:
    // bonus clips named only for what they show, or bare "S01E02.mkv".
    final fromFolders =
        (extra && (base.marker != _Marker.extra || base.untitled)) ||
        (base.marker == _Marker.episode && base.untitled);
    var title = base.title;
    var year = base.year;
    var season = base.season;
    final evidence = [...base.evidence];
    if (fromFolders) {
      final show = _showFolder(folders);
      if (show != null) {
        title = show.title;
        year = show.year ?? (extra ? null : year);
        evidence.add('folder:${show.folder}');
      }
    }
    if (extra) {
      evidence.add('extra');
      if (season == null) {
        for (final f in folders.reversed) {
          final m = RegExp(
            r'^(?:season|s)\s*(\d{1,2})$',
            caseSensitive: false,
          ).firstMatch(f.trim());
          if (m != null) {
            season = int.parse(m[1]!);
            break;
          }
        }
      }
    }
    return MediaNameEvidence(
      original: name,
      title: title,
      kind: extra ? (kind ?? MediaKind.movie) : base.kind,
      year: year,
      season: season,
      episodes: extra ? const [] : base.episodes,
      tags: base.tags,
      evidence: evidence,
      extra: extra,
      episodeTitle: extra ? null : base.episodeTitle,
    );
  }

  /// "Owner [Year] - Title" inside a folder that collects the owner's films
  /// ("Jet Li Movie Collection 1982-2008"): the part after the dash is the
  /// title. Without such a folder the name is left alone, since
  /// "Title [Year] - Group" is a common release pattern too.
  static ({String owner, int year, String title})? _collectionItem(
    String name,
    List<String> folders,
  ) {
    final stem = name.replaceFirst(
      RegExp(r'\.[a-z0-9]{2,5}$', caseSensitive: false),
      '',
    );
    final m = RegExp(r'^(.+?)\s*\[((?:19|20)\d{2})\]\s*-\s*(.+)$')
        .firstMatch(stem.replaceAll('_', ' '));
    if (m == null) return null;
    final owner = m[1]!.trim();
    if (owner.length < 3) return null;
    final key = owner.toLowerCase();
    final collects = folders.any((f) {
      final folder = f.toLowerCase();
      return folder.contains(key) &&
          RegExp(
            r'collection|filmography|anthology|合集|全集|\b(?:19|20)\d{2}\s*-\s*(?:19|20)\d{2}\b',
          ).hasMatch(folder);
    });
    if (!collects) return null;
    return (owner: owner, year: int.parse(m[2]!), title: m[3]!.trim());
  }

  /// The folder that owns a bonus clip at [path]: the nearest one above it
  /// that is neither a bonus folder nor a season/disc group. Null at the root.
  static String? hostFolder(String path) {
    final parts = path.split('/');
    parts.removeLast();
    while (parts.isNotEmpty) {
      final f = parts.last.trim();
      if (f.isEmpty) return null;
      if (!_extraFolder.hasMatch(f) && !_groupFolder.hasMatch(f)) {
        return parts.join('/');
      }
      parts.removeLast();
    }
    return null;
  }

  /// The nearest folder above the file that names the series itself.
  ({String title, int? year, String folder})? _showFolder(
    List<String> folders,
  ) {
    for (final folder in folders.reversed) {
      final f = folder.trim();
      if (_extraFolder.hasMatch(f) || _groupFolder.hasMatch(f)) continue;
      final parsed = _parse(f);
      final title = parsed.title
          // "Show - Complete Season 1,2,3 + Extras", "Show Season 1-11 S01-S11"
          .replaceFirst(
            RegExp(
              r'(?:^|[\s\-])(?:the\s+)?(?:complete\s+)?(?:seasons?|series)\b.*$|\bS\d{1,2}\s*-\s*S?\d{1,2}\b.*$|\+.*$'
              // Season packs: "Show.S02.1080p", "Show S01 COMPLETE", "Show - S01 - 2160p".
              r'|\bS\d{1,2}(?:\s*E\d{1,3})*\b.*$|\bcomplete\b.*$',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'^[\s\-]+|[\s\-,]+$'), '')
          .trim();
      if (title.isEmpty || parsed.untitled) continue;
      return (title: _stripCountry(title), year: parsed.year, folder: f);
    }
    return null;
  }

  /// "Shameless (US)": providers list the title without the country tag.
  static String _stripCountry(String title) {
    final stripped = title
        .replaceFirst(
          RegExp(r'\s*\((?:US|UK|AU|CA|NZ|IE|JP|KR)\)?$', caseSensitive: false),
          '',
        )
        .trim();
    return stripped.isEmpty ? title : stripped;
  }

  _Parsed _parse(String name, {String? parent, MediaKind? kind}) {
    var text = name.replaceFirst(
      RegExp(r'\.[a-z0-9]{2,5}$', caseSensitive: false),
      '',
    );
    final tags = <String>[];
    final evidence = <String>[];
    int? year, season;
    final episodes = <int>[];
    var marker = _Marker.none;
    final spaced = text.replaceAll(RegExp(r'[._]'), ' ');
    final episode = RegExp(
      r'\bS(\d{1,2})((?:E\d{1,3})+)',
      caseSensitive: false,
    ).firstMatch(spaced);
    // "Show Season 6 Episode 21 - Title"
    final spelled = RegExp(
      r'\bSeason\s*(\d{1,2})\s*Episode\s*(\d{1,3})\b',
      caseSensitive: false,
    ).firstMatch(spaced);
    // "Show - S01 Extra - Title", "Show - S05Extra - Title", "Show Season 7 Extra 02"
    final extra = RegExp(
      r'\b(?:S|Season\s*)(\d{1,2})\s*Extras?\b',
      caseSensitive: false,
    ).firstMatch(spaced);
    var cut = text.length;
    int? markerEnd;
    if (episode != null) {
      markerEnd = episode.end;
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
      marker = _Marker.episode;
    } else if (spelled != null) {
      markerEnd = spelled.end;
      season = int.parse(spelled[1]!);
      episodes.add(int.parse(spelled[2]!));
      cut = spelled.start;
      evidence.add(spelled[0]!);
      kind = MediaKind.episode;
      marker = _Marker.episode;
    } else if (extra != null) {
      season = int.parse(extra[1]!);
      cut = extra.start;
      evidence.add(extra[0]!);
      marker = _Marker.extra;
    }
    final chinese = RegExp(r'第\s*(\d+)\s*季(?:\s*第?\s*(\d+)\s*集)?')
        .firstMatch(text);
    if (chinese != null && marker == _Marker.none) {
      season = int.parse(chinese[1]!);
      if (chinese[2] != null) episodes.add(int.parse(chinese[2]!));
      cut = cut < chinese.start ? cut : chinese.start;
      kind = episodes.isEmpty ? MediaKind.season : MediaKind.episode;
      evidence.add(chinese[0]!);
      marker = _Marker.episode;
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
    // Text after an episode marker is the episode's own title
    // ("Show S01E22 Airport 2010"); a year there is not the series' year.
    final markerAt = marker == _Marker.none ? null : cut;
    final normalized = spaced;
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
    // "01.1981.Taps.1920x1040": a short number before the year is a
    // collection index when title words follow the year.
    final indexed = RegExp(
      r'\d{1,3}\s+(?=(?:19|20)\d{2}\s+[^\W\d_]{2})',
      unicode: true,
    ).matchAsPrefix(normalized, start);
    for (final match in years) {
      if (markerAt != null && match.start >= markerAt) break;
      if (indexed != null && match.start == indexed.end) break;
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
      r'\b(?:2160p|1080p|720p|480p|4K|BluRay|BDRip|WEB[ ._-]?DL|WEBRip|HDR10\+?|HDR|DV|x26[45]|H[ .]?26[45]|HEVC|AV1|REMUX|AAC|DTS|\d{3,4}x\d{3,4}|CD\s?\d{1,2}|DIS[CK]\s?\d{1,2})\b',
      caseSensitive: false,
    );
    var episodeEnd = normalized.length;
    for (final match in technical.allMatches(normalized)) {
      if (match.start < start) continue;
      tags.add(match[0]!);
      cut = cut < match.start ? cut : match.start;
      if (markerEnd != null && match.start >= markerEnd) {
        episodeEnd = episodeEnd < match.start ? episodeEnd : match.start;
      }
    }
    String? episodeTitle;
    if (markerEnd != null && markerEnd < episodeEnd) {
      final t = normalized
          .substring(markerEnd, episodeEnd)
          .replaceFirst(
            RegExp(
              r'^[\s\-:]*(?:(?:INTERNAL|PROPER|REPACK|REAL|READNFO)\b[\s\-]*)*',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'^[\s\-:]+|[\s\-:(\[]+$'), '')
          .trim();
      if (RegExp(r'[^\W\d_]{2}', unicode: true).hasMatch(t)) episodeTitle = t;
    }
    // "1997.Tomorrow.Never.Dies.1920x820": a leading year is the release year
    // only when no other year exists and title words follow before the tags.
    var titleStart = start;
    if (year == null) {
      final from = indexed?.end ?? start;
      if (indexed != null) evidence.add('index:${indexed[0]!.trim()}');
      final leading = RegExp(r'(?:19|20)\d{2}\s+')
          .matchAsPrefix(normalized, from);
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
    return _Parsed(
      title: text.isEmpty ? name : _stripCountry(text),
      untitled: text.isEmpty,
      kind: kind ?? MediaKind.movie,
      year: year,
      season: season,
      episodes: episodes,
      tags: tags,
      evidence: evidence,
      marker: marker,
      episodeTitle: episodeTitle,
    );
  }
}

enum _Marker { none, episode, extra }

class _Parsed {
  const _Parsed({
    required this.title,
    required this.untitled,
    required this.kind,
    required this.year,
    required this.season,
    required this.episodes,
    required this.tags,
    required this.evidence,
    required this.marker,
    this.episodeTitle,
  });
  final String title;
  final bool untitled;
  final MediaKind kind;
  final int? year;
  final int? season;
  final List<int> episodes;
  final List<String> tags;
  final List<String> evidence;
  final _Marker marker;
  final String? episodeTitle;
}
