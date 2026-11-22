import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/remote_access/remote_access_service.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/features/settings/scan_extensions_page.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  testWidgets('chips toggle presets, custom ones are added and saved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final config = SourceConfigurationService(sqlite3.openInMemory());
    final manager = SourceManager(
      configuration: config,
      remoteAccess: RemoteAccessService.memory(),
    );
    await manager.save(
      const SourceConfig(
        id: 'nas',
        kind: SourceKind.jellyfin,
        name: 'NAS',
        address: 'http://nas.invalid:8096',
        userId: 'user',
      ),
      'token',
    );
    await manager.setScanExtensions(['mp4', 'mkv', 'strm']);
    addTearDown(() async {
      await manager.dispose();
      config.close();
    });
    await tester.pumpWidget(
      TestApp(home: ScanExtensionsPage(sources: manager)),
    );
    await tester.pumpAndSettle();

    // A non-preset value lands under Custom as a removable chip.
    expect(find.byKey(const ValueKey('scan-ext-strm')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('scan-ext-mkv')));
    await tester.tap(find.byKey(const ValueKey('scan-ext-flac')));
    await tester.enterText(
      find.byKey(const ValueKey('scan-ext-input')),
      '.ISO',
    );
    await tester.tap(find.byKey(const ValueKey('scan-ext-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scan-ext-iso')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('scan-ext-input')), 'a-b');
    await tester.tap(find.byKey(const ValueKey('scan-ext-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scan-ext-a-b')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('scan-ext-strm')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('scan-ext-save')));
    await tester.tap(find.byKey(const ValueKey('scan-ext-save')));
    await tester.pumpAndSettle();
    expect(manager.scanExtensions, ['mp4', 'flac', 'iso']);
  });
}
