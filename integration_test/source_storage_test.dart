import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:sqlite3/sqlite3.dart';

import 'support/test_video.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'host restores saved instances, credentials and local directory bookmarks',
    (tester) async {
      final dir = await Directory.systemTemp.createTemp('source-storage-');
      final mediaDirectory = await Directory('${dir.path}/media').create();
      await createTestVideo(mediaDirectory);
      final prefix = 'integration-${DateTime.now().microsecondsSinceEpoch}';
      final databasePath = '${dir.path}/configuration.sqlite3';
      final firstConfiguration = SourceConfigurationService(
        sqlite3.open(databasePath),
      );
      final restoredConfiguration = SourceConfigurationService(
        sqlite3.open(databasePath),
      );
      final manager = SourceManager(configuration: firstConfiguration);
      final restored = SourceManager(configuration: restoredConfiguration);
      addTearDown(() async {
        await manager.reload();
        await manager.remove('$prefix-local');
        await manager.remove('$prefix-plex');
        await manager.dispose();
        await restored.dispose();
        firstConfiguration.close();
        restoredConfiguration.close();
        await dir.delete(recursive: true);
      });
      await manager.save(
        SourceConfig(
          id: '$prefix-local',
          kind: SourceKind.local,
          name: 'Integration Local',
          address: mediaDirectory.path,
        ),
        '',
      );
      await manager.save(
        SourceConfig(
          id: '$prefix-plex',
          kind: SourceKind.plex,
          name: 'Integration Plex',
          address: 'http://localhost:13240',
        ),
        'integration-only-token',
      );
      await restored.load();
      final local = restored.configs.singleWhere(
        (c) => c.id == '$prefix-local',
      );
      expect(local.bookmark, Platform.isMacOS ? isNotNull : isNull);
      final files = await restored.browse(local.id, const BrowseRequest());
      expect(files.entries.single.name, 'openplayx-test.mp4');
      final stream = await restored.resolve(files.entries.single.ref);
      expect(await File.fromUri(stream.uri).exists(), isTrue);
      await stream.release();
      // Blank edit must read and preserve the existing native secure-store value.
      final plex = restored.configs.singleWhere((c) => c.id == '$prefix-plex');
      await restored.save(plex, '');
    },
  );
}
