import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/metadata_capability.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/services/artwork/artwork_service.dart';

import 'metadata_test.dart' show FixtureSources;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'artwork cache evicts regenerable files, retains selections and rejects foreign URLs',
    (tester) async {
      await tester.runAsync(() async {
        final root = await Directory.systemTemp.createTemp(
          'openplayx-artwork-',
        );
        final png = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6zX8AAAAASUVORK5CYII=',
        );
        final selections = <ArtworkDescriptor>[];
        final service = ArtworkService(
          FixtureSources(root),
          directory: Directory('${root.path}/cache'),
          cacheQuotaBytes: png.length * 2,
          retainedArtwork: () => selections,
        );
        Future<ArtworkDescriptor> image(String name) async {
          final file = await File('${root.path}/$name.png').writeAsBytes(png);
          return ArtworkDescriptor(
            id: name,
            type: 'poster',
            source: ResourceRef('files', file.path),
          );
        }

        try {
          final a = await image('a'),
              b = await image('b'),
              c = await image('c');
          selections.add(a);
          final first = await service.load(a), second = await service.load(b);
          await service.load(c);
          expect(await first.exists(), isTrue);
          expect(await second.exists(), isFalse);
          expect(await Directory('${root.path}/cache').list().length, 2);
          await expectLater(
            service.load(
              ArtworkDescriptor(
                id: 'foreign',
                type: 'poster',
                remote: Uri.parse('https://example.com/private.jpg'),
              ),
            ),
            throwsA(isA<PluginException>()),
          );
          await service.clear();
          expect(selections.single.id, 'a');
        } finally {
          service.dispose();
          await root.delete(recursive: true);
        }
      });
    },
  );
  testWidgets(
    'one candidate with different source variants uses different cache entries',
    (tester) async {
      await tester.runAsync(() async {
        final root = await Directory.systemTemp.createTemp(
          'openplayx-art-variants-',
        );
        final bytes = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6zX8AAAAASUVORK5CYII=',
        );
        final a = await File('${root.path}/a.png').writeAsBytes(bytes);
        final b = await File('${root.path}/b.png').writeAsBytes(bytes);
        final service = ArtworkService(
          FixtureSources(root),
          directory: Directory('${root.path}/cache'),
        );
        try {
          final first = await service.load(
            ArtworkDescriptor(
              id: 'same-candidate',
              type: 'poster',
              source: ResourceRef('files', a.path),
            ),
          );
          final second = await service.load(
            ArtworkDescriptor(
              id: 'same-candidate',
              type: 'poster',
              source: ResourceRef('files', b.path),
            ),
          );
          expect(first.path, isNot(second.path));
          expect(await first.exists(), isTrue);
          expect(await second.exists(), isTrue);
          expect(
            service.cacheKey(
              ArtworkDescriptor(
                id: 'same',
                type: 'thumbnail',
                remote: Uri.parse('https://image.tmdb.org/t/p/w92/a.jpg'),
              ),
            ),
            isNot(
              service.cacheKey(
                ArtworkDescriptor(
                  id: 'same',
                  type: 'thumbnail',
                  remote: Uri.parse('https://image.tmdb.org/t/p/w300/a.jpg'),
                ),
              ),
            ),
          );
        } finally {
          service.dispose();
          await root.delete(recursive: true);
        }
      });
    },
  );
  test(
    'invalid attachment bytes never become a published image cache file',
    () async {
      final root = await Directory.systemTemp.createTemp('openplayx-bad-art-');
      final file = await File('${root.path}/bad.png')
          .writeAsString('<script>bad</script>');
      final cache = Directory('${root.path}/cache');
      final service = ArtworkService(FixtureSources(root), directory: cache);
      try {
        await expectLater(
          service.load(
            ArtworkDescriptor(
              id: 'bad',
              type: 'poster',
              source: ResourceRef('files', file.path),
            ),
          ),
          throwsA(isA<PluginException>()),
        );
        expect(await cache.list().length, 0);
      } finally {
        service.dispose();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'cache size counts downloaded files and drops to zero on clear',
    () async {
      final root = await Directory.systemTemp.createTemp('artwork-size');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final cache = Directory('${root.path}/cache');
      final service = ArtworkService(FixtureSources(root), directory: cache);
      addTearDown(service.dispose);
      expect(await service.cacheBytes(), 0);
      await Directory('${cache.path}/nested').create(recursive: true);
      await File('${cache.path}/a').writeAsBytes(List.filled(1000, 1));
      await File('${cache.path}/nested/b').writeAsBytes(List.filled(24, 1));
      expect(await service.cacheBytes(), 1024);
      await service.clear();
      expect(await service.cacheBytes(), 0);
    },
  );

  test('logos prefer UI language, then neutral, then English', () {
    ArtworkDescriptor logo(String id, String? lang) =>
        ArtworkDescriptor(id: id, type: 'logo', language: lang);
    final all = [
      logo('en', 'en'),
      logo('ja', 'ja'),
      logo('none', null),
      logo('zh', 'zh'),
      const ArtworkDescriptor(id: 'poster', type: 'poster', language: 'zh'),
    ];
    expect(ArtworkService.orderedLogos(all, 'zh_CN').map((a) => a.id), [
      'zh',
      'none',
      'en',
    ]);
    expect(ArtworkService.orderedLogos(all, 'en-US').map((a) => a.id), [
      'en',
      'none',
    ]);
    expect(ArtworkService.orderedLogos(all, '').map((a) => a.id), [
      'none',
      'en',
    ]);
  });

  testWidgets('title logo resolution skips logos with an opaque background', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final root = await Directory.systemTemp.createTemp('openplayx-logo-');
      // 20x8 RGBA: a white bar on a red box, and the same bar on clear.
      const fixtures = {
        'boxed': 'iVBORw0KGgoAAAANSUhEUgAAABQAAAAICAYAAAD5nd/tAAAAG0lEQVR4nGM4w8Dwn5qYgeYGkgpGDaRDpFCKATJgiCCZIOLMAAAAAElFTkSuQmCC',
        'clear': 'iVBORw0KGgoAAAANSUhEUgAAABQAAAAICAYAAAD5nd/tAAAAE0lEQVR4nGNgGHLgP4lg1MAhAAAdtr9BsOMipAAAAABJRU5ErkJggg==',
      };
      Future<ArtworkDescriptor> logo(String name) async {
        final file = await File('${root.path}/$name.png')
            .writeAsBytes(base64Decode(fixtures[name]!));
        return ArtworkDescriptor(
          id: '$name-${root.path}',
          type: 'logo',
          source: ResourceRef('files', file.path),
        );
      }

      final service = ArtworkService(
        FixtureSources(root),
        directory: Directory('${root.path}/cache'),
      );
      try {
        final boxed = await logo('boxed');
        final clear = await logo('clear');
        expect(service.cachedLogo([boxed, clear]), isNull);
        expect(await service.hasOpaqueEdges(boxed), isTrue);
        expect(await service.hasOpaqueEdges(clear), isFalse);
        expect((await service.resolveLogo([boxed, clear]))?.id, clear.id);
        expect(await service.resolveLogo([boxed]), isNull);
        final cached = service.cachedLogo([boxed, clear]);
        expect(cached?.logo?.id, clear.id);
        expect(cached?.file?.existsSync(), isTrue);
        expect(service.cachedLogo([boxed])?.logo, isNull);
      } finally {
        service.dispose();
        await root.delete(recursive: true);
      }
    });
  });
}
