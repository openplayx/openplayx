import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/remote_access/remote_access_service.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/settings/remote_access_settings_page.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  testWidgets(
    'settings separate JSON saving from apply and show service binding controls',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final config = SourceConfigurationService(sqlite3.openInMemory());
      final remote = RemoteAccessService.memory();
      var validations = 0;
      final manager = SourceManager(
        configuration: config,
        remoteAccess: remote,
        remoteCoreValidator: (_) async {
          validations++;
        },
      );
      await manager.save(
        const SourceConfig(
          id: 'nas',
          kind: SourceKind.jellyfin,
          name: 'Home NAS',
          address: 'http://nas.invalid:8096',
          userId: 'user',
        ),
        'fixture-token',
      );
      addTearDown(() async {
        await manager.dispose();
        config.close();
      });
      await tester.pumpWidget(
        TestApp(home: RemoteAccessSettingsPage(sources: manager)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('生效 0'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('remote-save')));
      await tester.pumpAndSettle();
      expect(remote.desired.revision, 1);
      expect(remote.active.revision, 0);
      expect(find.text('已保存但未生效'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('remote-apply')));
      await tester.pumpAndSettle();
      expect(remote.active.revision, 1);
      expect(validations, 1);
      expect(find.text('当前保存修订已应用'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(find.text('配置家庭远程访问'), findsOneWidget);
      await tester.tap(find.text('配置家庭远程访问'));
      await tester.pumpAndSettle();
      expect(find.text('远程连接设置'), findsOneWidget);
      expect(find.text('导入配对并填充表单'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
