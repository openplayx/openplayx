import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/metadata_capability.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/services/artwork/artwork_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../metadata/metadata_test.dart' show FixtureSources;

/// Lets the test pick limits far below the Settings choices.
class _QuotaSources extends FixtureSources {
  _QuotaSources(super.root);
  int mb = 1;
  @override
  int get artworkCacheQuotaMb => mb;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cache limit defaults, persists per device and rejects other values',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final service = SourceConfigurationService(sqlite3.openInMemory());
      final manager = SourceManager(configuration: service);
      addTearDown(() async {
        await manager.dispose();
        service.close();
      });
      expect(service.artworkCacheQuotaMb(), isNull);
      expect(
        manager.artworkCacheQuotaMb,
        SourceManager.defaultArtworkCacheQuotaMb,
      );
      expect(manager.artworkCacheQuotaMb, 256);

      await manager.setArtworkCacheQuotaMb(1024);
      expect(manager.artworkCacheQuotaMb, 1024);
      expect(service.artworkCacheQuotaMb(), 1024);

      await expectLater(
        manager.setArtworkCacheQuotaMb(300),
        throwsA(isA<PluginException>()),
      );
      expect(manager.artworkCacheQuotaMb, 1024);
    },
  );

  testWidgets(
    'every eviction reads the current limit; trim keeps retained art',
    (tester) async {
      await tester.runAsync(() async {
        final root = await Directory.systemTemp.createTemp('openplayx-quota-');
        addTearDown(() => root.delete(recursive: true));
        final cache = Directory('${root.path}/cache')..createSync();
        final sources = _QuotaSources(root);
        const kept = ArtworkDescriptor(
          id: 'kept',
          type: 'poster',
          remote: null,
          source: ResourceRef('files', '/kept.png'),
        );
        final service = ArtworkService(
          sources,
          directory: cache,
          retainedArtwork: () => [kept],
        );
        addTearDown(service.dispose);
        const kib400 = 400 * 1024;
        final start = DateTime(2026, 1, 1);
        File put(String name, int minute) => File('${cache.path}/$name')
          ..writeAsBytesSync(List.filled(kib400, 0))
          ..setLastModifiedSync(start.add(Duration(minutes: minute)));
        // Oldest first: the retained selection, then two regenerable files.
        final retained = put(service.cacheKey(kept), 0);
        final old = put('old', 1);
        final recent = put('recent', 2);

        expect(service.cacheQuotaBytes, 1024 * 1024);
        await service.trim();
        // 1200 KiB > 1 MiB: the oldest regenerable file goes, the retained one stays.
        expect(old.existsSync(), isFalse);
        expect(retained.existsSync(), isTrue);
        expect(recent.existsSync(), isTrue);

        // Lowering the setting applies on the next trim without a new instance;
        // retained art survives even when it alone exceeds the limit.
        sources.mb = 0;
        expect(service.cacheQuotaBytes, 0);
        await service.trim();
        expect(recent.existsSync(), isFalse);
        expect(retained.existsSync(), isTrue);
      });
    },
  );

  test('an explicit limit (tests, embedders) still overrides the setting', () {
    final sources = _QuotaSources(Directory.systemTemp)..mb = 512;
    final fixed = ArtworkService(sources, cacheQuotaBytes: 4096);
    addTearDown(fixed.dispose);
    expect(fixed.cacheQuotaBytes, 4096);
    final shared = ArtworkService(sources);
    addTearDown(shared.dispose);
    expect(shared.cacheQuotaBytes, 512 * 1024 * 1024);
  });
}
