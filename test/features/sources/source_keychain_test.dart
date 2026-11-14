import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/sources/source_page.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  testWidgets(
    'opening, refreshing and rebuilding sources needs no secret; a missing '
    'one fails on first use',
    (tester) async {
      final service = SourceConfigurationService(sqlite3.openInMemory());
      // Kinds that need a token, so an empty one fails before any network.
      for (final kind in [
        SourceKind.emby,
        SourceKind.plex,
        SourceKind.jellyfin,
      ]) {
        service.save(
          SourceConfig(
            id: kind.name,
            kind: kind,
            name: kind.label,
            address: 'http://127.0.0.1:32400',
            userId: kind == SourceKind.plex ? '' : 'test-user',
          ),
          expectedRevision: 0,
          // Saved but empty: shown as configured, rejected on first use.
          secret: '',
        );
      }
      final manager = SourceManager(configuration: service);
      addTearDown(() async {
        await manager.dispose();
        service.close();
      });

      await tester.pumpWidget(TestApp(home: SourcePage(manager: manager)));
      await tester.pumpAndSettle();
      expect(find.text('待验证'), findsNWidgets(3));
      expect(find.byType(SegmentedButton<bool>), findsNothing);

      // Reloading configuration (the page's own refresh path) reads nothing.
      await manager.reload();
      await tester.pumpAndSettle();
      await tester.pumpWidget(TestApp(home: SourcePage(manager: manager)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // A saved reference is not proof that the secret still exists. Check it
      // once on actual use and fail before attempting a network connection.
      for (final id in ['emby', 'plex', 'jellyfin']) {
        await expectLater(
          manager.browse(id, const BrowseRequest()),
          throwsA(
            isA<PluginException>().having(
              (e) => e.code,
              'code',
              'authRequired',
            ),
          ),
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
