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
}
