import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/sources/source_page.dart';
import 'package:sqlite3/sqlite3.dart';

class _UnavailableKeychain extends FlutterSecureStorage {
  int reads = 0;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    reads++;
    return null;
  }
}

void main() {
  testWidgets(
    'opening, refreshing and rebuilding sources never reads keychain',
    (tester) async {
      final service = SourceConfigurationService(sqlite3.openInMemory());
      for (final kind in [
        SourceKind.smb,
        SourceKind.plex,
        SourceKind.jellyfin,
      ]) {
        service.save(
          SourceConfig(
            id: kind.name,
            kind: kind,
            name: kind.label,
            address: kind == SourceKind.smb
                ? 'smb://127.0.0.1/share'
                : 'http://127.0.0.1:32400',
            userId: kind == SourceKind.jellyfin ? 'test-user' : '',
            credentialRef: 'source.${kind.name}.saved',
          ),
          expectedRevision: 0,
        );
      }
      final keychain = _UnavailableKeychain();
      final manager = SourceManager(
        configuration: service,
        credentials: keychain,
      );
      addTearDown(() async {
        await manager.dispose();
        service.close();
      });

      await tester.pumpWidget(TestApp(home: SourcePage(manager: manager)));
      await tester.pumpAndSettle();
      expect(find.textContaining('尚未验证'), findsNWidgets(3));
      expect(find.byType(SegmentedButton<bool>), findsNothing);
      expect(keychain.reads, 0);

      // Reloading configuration (the page's own refresh path) reads nothing.
      await manager.reload();
      await tester.pumpAndSettle();
      await tester.pumpWidget(TestApp(home: SourcePage(manager: manager)));
      await tester.pumpAndSettle();
      expect(keychain.reads, 0);
      expect(tester.takeException(), isNull);

      // A saved reference is not proof that the secret still exists. Check it
      // once on actual use and fail before attempting a network connection.
      for (final id in ['smb', 'plex', 'jellyfin']) {
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
      expect(keychain.reads, 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
