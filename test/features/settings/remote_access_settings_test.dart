import 'dart:convert';

import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/remote_access/remote_access_service.dart';
import 'package:openplayx/data/remote_access/remote_config.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/settings/remote_access_settings_page.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  testWidgets(
    'one import sets the Relay connection and lists proxies with their sources',
    (tester) async {
      // A tap on something covered (e.g. by a toast) fails the test.
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
      final config = SourceConfigurationService(sqlite3.openInMemory());
      final remote = RemoteAccessService.memory();
      var validations = 0;
      final manager = SourceManager(
        configuration: config,
        remoteAccess: remote,
        remoteCoreValidator: (_, _) async {
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
          remote: SourceRemote(proxy: 'jellyfin'),
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
      expect(find.byKey(const ValueKey('remote-unconfigured')), findsOneWidget);
      expect(find.text('探测与连接策略'), findsNothing);
      expect(find.byKey(const ValueKey('remote-pairing')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('remote-import')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('remote-pairing')),
        jsonEncode({
          'outbound': {
            'type': 'vless',
            'tag': 'relay',
            'server': 'relay.example',
            'server_port': 443,
            'uuid': '11111111-1111-4111-8111-111111111111',
            'tls': {'enabled': true, 'server_name': 'relay.example'},
          },
          'proxies': [
            {'name': 'smb', 'remotePort': 18445},
            {'name': 'jellyfin', 'remotePort': 18096},
          ],
        }),
      );
      await tester.tap(find.byKey(const ValueKey('remote-import-confirm')));
      await tester.pumpAndSettle();
      expect(validations, 1);
      expect(remote.network.configured, isTrue);
      expect(manager.configs.single.remoteAccess!.remotePort, 18096);
      await tester.drag(find.byType(ListView), const Offset(0, 1500));
      await tester.pumpAndSettle();
      expect(find.text('relay.example:443'), findsOneWidget);
      expect(find.byKey(const ValueKey('remote-proxy-smb')), findsOneWidget);
      expect(find.text('来源：Home NAS'), findsOneWidget);
      expect(find.textContaining('不在当前配置中'), findsNothing);
      // Success is a toast at the top; while it shows, the bottom actions
      // stay tappable (the tap below would miss if the toast covered them).
      expect(find.text('已导入并生效。'), findsOneWidget);
      // The actions sit at the bottom of the page.
      await tester.ensureVisible(find.byKey(const ValueKey('remote-clear')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('remote-clear')));
      await tester.pumpAndSettle();
      // 清空 is confirmed in a second step.
      expect(remote.network.configured, isTrue);
      await tester.tap(find.text('清空').last);
      await tester.pumpAndSettle();
      expect(remote.network.configured, isFalse);
      expect(remote.network.proxies, isEmpty);
      expect(find.byKey(const ValueKey('remote-server')), findsNothing);
      expect(find.byKey(const ValueKey('remote-proxy-smb')), findsNothing);
      expect(find.byKey(const ValueKey('remote-unconfigured')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
