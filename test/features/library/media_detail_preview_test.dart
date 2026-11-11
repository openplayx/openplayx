import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/app/theme/app_theme_controller.dart';
import 'package:openplayx/core/plugins/metadata_capability.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/library/media_detail_page.dart';
import 'package:openplayx/services/artwork/artwork_service.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:sqlite3/sqlite3.dart';

import 'library_page_test.dart' show Sources;

/// Synthetic artwork by type, so previews never depend on real posters.
class PreviewArtwork extends ArtworkService {
  PreviewArtwork(super.sources, this.files);
  final Map<String, File> files;
  @override
  Future<File> load(ArtworkDescriptor artwork) async =>
      files[artwork.id] ??
      files['${artwork.type}:${artwork.id.hashCode.abs() % 6}'] ??
      files[artwork.type]!;
}

/// A series with one season of twelve episodes.
class SeasonSources extends Sources {
  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) async {
    if (request.node == null) {
      return const BrowseResult([
        SourceEntry(
          ResourceRef('s', 'show'),
          'Show',
          isFolder: true,
          media: SourceMediaInfo(id: 'show', title: 'Show', kind: 'series'),
        ),
      ]);
    }
    if (request.node!.id == 'show') {
      return const BrowseResult([
        SourceEntry(
          ResourceRef('s', 'season'),
          'Season 1',
          isFolder: true,
          media: SourceMediaInfo(
            id: 'season',
            title: 'Season 1',
            kind: 'season',
            parentId: 'show',
            season: 1,
          ),
        ),
      ]);
    }
    return BrowseResult([
      for (var e = 1; e <= 12; e++)
        SourceEntry(
          ResourceRef('s', 'e$e.mkv'),
          'e$e.mkv',
          isFolder: false,
          media: SourceMediaInfo(
            id: 'e$e',
            title: _episodeTitles[e - 1],
            kind: 'episode',
            parentId: 'season',
            season: 1,
            episode: e,
          ),
        ),
    ]);
  }
}

const _episodeTitles = [
  '试播集',
  '灯塔守夜人',
  '潮汐来信',
  '北岸的雾',
  '迷路的渡轮',
  '三号码头',
  '冬至',
  '回声',
  '无人岛',
  '退潮',
  '旧地图',
  '归航',
];

Future<File> _paint(
  String path,
  int width,
  int height,
  void Function(Canvas, Size) draw,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  draw(canvas, Size(width.toDouble(), height.toDouble()));
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return File(path)..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void _scene(Canvas canvas, Size size, int seed) {
  final random = Random(seed);
  final palettes = [
    [const Color(0xFF1B3A4B), const Color(0xFFE09F3E), const Color(0xFF9E2A2B)],
    [const Color(0xFF2B2D42), const Color(0xFF8D99AE), const Color(0xFFEF233C)],
    [const Color(0xFF3D348B), const Color(0xFF7678ED), const Color(0xFFF7B801)],
    [const Color(0xFF264653), const Color(0xFF2A9D8F), const Color(0xFFE76F51)],
    [const Color(0xFF5F0F40), const Color(0xFF9A031E), const Color(0xFFFB8B24)],
    [const Color(0xFF0B3954), const Color(0xFF087E8B), const Color(0xFFBFD7EA)],
  ];
  final colors = palettes[seed % palettes.length];
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
        colors[0],
        Color.lerp(colors[0], Colors.black, 0.5)!,
      ]),
  );
  for (var i = 0; i < 14; i++) {
    final center = Offset(
      random.nextDouble() * size.width,
      random.nextDouble() * size.height,
    );
    final radius = (0.15 + random.nextDouble() * 0.35) * size.shortestSide;
    final color = colors[1 + random.nextInt(2)];
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(center, radius, [
          color.withValues(alpha: 0.85),
          color.withValues(alpha: 0),
        ]),
    );
  }
  // Two silhouettes give the frame a subject.
  final figure = Paint()..color = const Color(0xCC0A0A0F);
  for (final x in [0.62, 0.8]) {
    final cx = size.width * x;
    canvas.drawCircle(
      Offset(cx, size.height * 0.36),
      size.height * 0.11,
      figure,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, size.height * 0.85),
          width: size.height * 0.42,
          height: size.height * 0.75,
        ),
        Radius.circular(size.height * 0.15),
      ),
      figure,
    );
  }
}

void _face(Canvas canvas, Size size, int seed) {
  final tones = [
    const Color(0xFFE8C4A0),
    const Color(0xFFC99A76),
    const Color(0xFF8D5B3E),
    const Color(0xFFF1D3B8),
  ];
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
        HSLColor.fromAHSL(1, (seed * 47) % 360.0, 0.25, 0.55).toColor(),
        HSLColor.fromAHSL(1, (seed * 47) % 360.0, 0.25, 0.3).toColor(),
      ]),
  );
  final skin = Paint()..color = tones[seed % tones.length];
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.42,
      height: size.height * 0.52,
    ),
    skin,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 1.05),
        width: size.width * 0.9,
        height: size.height * 0.5,
      ),
      Radius.circular(size.width * 0.3),
    ),
    Paint()..color = const Color(0xFF1C1C22),
  );
  canvas.drawArc(
    Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.32),
      width: size.width * 0.46,
      height: size.height * 0.36,
    ),
    pi,
    pi,
    true,
    Paint()..color = const Color(0xFF2B1D14),
  );
}

void _logo(Canvas canvas, Size size, String text) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(textAlign: TextAlign.center, maxLines: 1),
        )
        ..pushStyle(
          ui.TextStyle(
            color: const Color(0xFF7FD6F5),
            fontSize: size.height * 0.62,
            fontWeight: FontWeight.w900,
            fontFamily: 'PingFang SC',
            letterSpacing: 6,
            shadows: const [Shadow(color: Color(0x88000000), blurRadius: 8)],
          ),
        )
        ..addText(text);
  final paragraph = builder.build()
    ..layout(ui.ParagraphConstraints(width: size.width));
  canvas.drawParagraph(
    paragraph,
    Offset(0, (size.height - paragraph.height) / 2),
  );
}

Future<void> _loadFonts(WidgetTester tester) async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(Uri.decodeFull(font['asset'] as String)));
    }
    await tester.runAsync(loader.load);
  }
  // CJK text needs a system font on the host running the preview.
  for (final path in [
    const String.fromEnvironment('OPENPLAYX_PREVIEW_CJK_FONT'),
    '/System/Library/Fonts/Hiragino Sans GB.ttc',
  ]) {
    if (path.isEmpty || !File(path).existsSync()) continue;
    final bytes = File(path).readAsBytesSync();
    final loader = FontLoader('PingFang SC')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await tester.runAsync(loader.load);
    break;
  }
}

/// Opt-in reference renders of the detail page next to the design captures:
/// flutter test test/features/library/media_detail_preview_test.dart \
///   --dart-define=OPENPLAYX_DETAIL_PREVIEW_DIR=/tmp/openplayx-detail
void main() {
  const output = String.fromEnvironment('OPENPLAYX_DETAIL_PREVIEW_DIR');
  testWidgets('export movie and series detail pages', (tester) async {
    await _loadFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final dir = Directory(output)..createSync(recursive: true);
    final art = Directory('${dir.path}/art')..createSync();
    final files = <String, File>{};
    await tester.runAsync(() async {
      files['backdrop'] = await _paint(
        '${art.path}/backdrop.png',
        1280,
        720,
        (c, s) => _scene(c, s, 0),
      );
      files['series-backdrop'] = await _paint(
        '${art.path}/series-backdrop.png',
        1280,
        720,
        (c, s) => _scene(c, s, 2),
      );
      files['poster'] = await _paint(
        '${art.path}/poster.png',
        500,
        750,
        (c, s) => _scene(c, s, 1),
      );
      for (var i = 0; i < 6; i++) {
        files['poster:$i'] = await _paint(
          '${art.path}/poster$i.png',
          500,
          750,
          (c, s) => _scene(c, s, i + 3),
        );
        files['thumbnail:$i'] = await _paint(
          '${art.path}/still$i.png',
          400,
          225,
          (c, s) => _scene(c, s, i + 7),
        );
        files['profile:$i'] = await _paint(
          '${art.path}/face$i.png',
          185,
          185,
          (c, s) => _face(c, s, i),
        );
      }
      files['thumbnail'] = files['thumbnail:0']!;
      files['profile'] = files['profile:0']!;
      files['logo'] = await _paint(
        '${art.path}/logo.png',
        600,
        200,
        (c, s) => _logo(c, s, '雾港来信'),
      );
    });

    final library = LibraryService(sqlite3.openInMemory());
    final sources = SeasonSources();
    final collection = library.defaultLibrary();
    String movie(String file, Map<String, dynamic> fields, int n) {
      final id = library.register(
        SourceEntry(ResourceRef('s', '/$file'), file, isFolder: false),
      );
      library.addManual(collection, id);
      library.transaction(
        () => library.metadata.apply(
          id,
          MetadataRecord(
            ref: MetadataRef('tmdb', MediaKind.movie, '$n'),
            fields: fields,
            artwork: [
              ArtworkDescriptor(id: 'poster:${n % 6}', type: 'poster'),
              if (n == 1)
                const ArtworkDescriptor(id: 'backdrop', type: 'backdrop'),
            ],
          ),
          sourceKey: 'tmdb',
          authority: 100,
          expectedRevision: 0,
          operationId: 'preview-$n',
          select: true,
        ),
      );
      return id;
    }

    const cast = [
      ('林知远', '陈默'),
      ('苏晚晴', 'Wong Chia Chi / Mrs. Mak'),
      ('周屿', 'Mrs. Yee'),
      ('顾北辰', 'Kuang Yu Min'),
      ('沈若溪', 'Old Wu'),
      ('陆川', 'Lai Shu Jin'),
      ('许清和', 'Huang Lei'),
      ('江离', 'Liang Jun Sheng'),
      ('叶知秋', 'Tsao'),
    ];
    final movieId = movie('rain.mkv', {
      'title': '雨夜行动',
      'originalTitle': 'Operation Rainfall',
      'year': 2007,
      'airDate': '2007-09-24',
      'countries': ['US'],
      'genres': ['动作', '剧情', '爱情', '惊悚'],
      'certification': 'R',
      'runtime': 157,
      'overview': '本是港湾大学学生的林知远因战事辗转来到香港读书，她在学校加入了青年话剧社，他们排演的爱国剧目更激起了大家的热情。当得知特务头子正在香港时，他们便密谋了一场危险的行动，而这场行动将改变所有人的命运。',
      'ratings': {
        'tmdb': {'value': 7.3, 'max': 10},
        'imdb': {'value': 7.5, 'max': 10},
        'rottentomatoes': {'value': 73, 'max': 100},
      },
      'directors': ['李安然'],
      'directorProfiles': {'李安然': 'https://image.tmdb.org/t/p/w185/d.jpg'},
      'cast': [
        for (final (i, (name, role)) in cast.indexed)
          {
            'name': name,
            'role': role,
            'profile': 'https://image.tmdb.org/t/p/w185/p$i.jpg',
          },
      ],
      'collection': {'id': '9', 'name': '雨夜系列'},
    }, 1);
    for (final (i, (title, date, score)) in [
      ('雨夜行动 2', '2010-05-24', 6.1),
      ('雨夜行动 3：破晓', '2013-04-25', 6.8),
      ('雨夜行动 4：幽灵', '2016-12-07', 7.1),
      ('雨夜行动 5：归途', '2019-07-28', 7.2),
      ('雨夜行动 6：全面瓦解', '2022-07-25', 7.5),
    ].indexed) {
      movie('rain${i + 2}.mkv', {
        'title': title,
        'airDate': date,
        'year': int.parse(date.substring(0, 4)),
        'ratings': {
          'tmdb': {'value': score, 'max': 10},
        },
        'collection': {'id': '9'},
      }, i + 2);
    }

    final binding = library.bind(collection, 's', name: 'TV');
    await tester.runAsync(() => library.scan(binding, sources));
    final show = library
        .query(collection, search: 'Show')
        .firstWhere((m) => m['title'] == 'Show');
    library.transaction(
      () => library.metadata.apply(
        show['id'] as String,
        MetadataRecord(
          ref: const MetadataRef('tmdb', MediaKind.series, '34307'),
          fields: {
            'kind': 'series',
            'title': '雾港来信',
            'year': 2011,
            'airDate': '2011-01-09',
            'countries': ['US'],
            'genres': ['剧情', '喜剧'],
            'certification': 'TV-MA',
            'overview': '父亲失踪后又出现在港口小镇，他努力戒酒却没有成功；为了守住灯塔，大女儿不惜与镇上的人周旋；二儿子爱上了一个拥有好车、大钱包和大秘密的渔夫；小儿子开始接受真实的自己，这让一家人的生活再起波澜。',
            'ratings': {
              'tmdb': {'value': 7.9, 'max': 10},
              'imdb': {'value': 8.5, 'max': 10},
              'trakt': {'value': 8.8, 'max': 10},
            },
            'cast': [
              for (final (i, (name, role)) in cast.indexed)
                {
                  'name': name,
                  'role': role,
                  'profile': 'https://image.tmdb.org/t/p/w185/s$i.jpg',
                },
            ],
          },
          artwork: const [
            ArtworkDescriptor(id: 'series-backdrop', type: 'backdrop'),
            ArtworkDescriptor(id: 'logo', type: 'logo', language: 'zh'),
          ],
        ),
        sourceKey: 'tmdb',
        authority: 100,
        expectedRevision: library.metadata.revision(show['id'] as String),
        operationId: 'preview-show',
        select: true,
      ),
    );
    final episode =
        library.query(collection, search: '灯塔守夜人').single['id'] as String;
    final resource = library.resources(episode).single['id'] as String;
    library.saveProgress(
      resource,
      library.beginSession(resource),
      const Duration(minutes: 18),
      const Duration(minutes: 50),
    );

    final artwork = PreviewArtwork(sources, files);
    final targets = {
      'movie': library
          .query(collection, search: '雨夜行动')
          .firstWhere((m) => m['id'] == movieId),
      'series': library.query(collection, search: '雾港来信').first,
    };
    for (final size in const [
      Size(817, 800),
      Size(390, 844),
      Size(1280, 860),
    ]) {
      tester.view.physicalSize = size;
      for (final MapEntry(key: name, value: media) in targets.entries) {
        final appearance = AppThemeController(initialLanguage: 'zh-Hans');
        final boundary = GlobalKey();
        // Image files are read and decoded on the real clock.
        await tester.runAsync(() async {
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: OpenPlayXApp(
                appearance: appearance,
                home: MediaDetailPage(
                  service: library,
                  sources: sources as SourceManager,
                  artwork: artwork,
                  media: media,
                  play: (_, _) async {},
                  resourceLabel: (_) => '',
                ),
              ),
            ),
          );
          for (var i = 0; i < 8; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 150));
            await tester.pump(const Duration(milliseconds: 300));
          }
        });
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          await File('${dir.path}/$name-${size.width.toInt()}.png')
              .writeAsBytes(bytes);
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
        appearance.dispose();
      }
    }
    library.close();
  }, skip: output.isEmpty);
}
