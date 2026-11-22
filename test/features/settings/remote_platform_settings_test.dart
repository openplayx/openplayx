import 'dart:convert';

import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/remote_access/remote_access_service.dart';
import 'package:openplayx/data/remote_access/relay_subscription.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/features/settings/remote_access_settings_page.dart';

import '../../data/remote_access/relay_subscription_test.dart' show profile;

void main() {
  testWidgets('signed-out registration submits email without logging in', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final db = sqlite3.openInMemory();
    final remote = RemoteAccessService(
      db,
      subscription: RelaySubscription(
        db,
        client: MockClient((req) async {
          requests.add(req);
          return http.Response('{"status":"accepted"}', 202);
        }),
      ),
    );
    final config = SourceConfigurationService(sqlite3.openInMemory());
    final manager = SourceManager(configuration: config, remoteAccess: remote);
    addTearDown(() async {
      await manager.dispose();
      config.close();
      db.close();
    });
    await tester.pumpWidget(
      TestApp(home: RemoteAccessSettingsPage(sources: manager)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('relay-platform-register')),
    );
    await tester.tap(find.byKey(const ValueKey('relay-platform-register')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('relay-registration-email')),
        matching: find.byType(EditableText),
      ),
      'owner@example.com',
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('relay-registration-submit')));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump(const Duration(seconds: 1));
    expect(requests.single.url.path, '/v1/auth/registration/request');
    expect(jsonDecode(requests.single.body), {'email': 'owner@example.com'});
    expect(remote.account.signedIn, isFalse);
    expect(tester.takeException(), isNull);
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets('platform defaults and restoration fit a $width viewport', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = sqlite3.openInMemory();
      final client = MockClient(
        (req) async => http.Response(
          jsonEncode(
            req.url.path == '/v1/auth/login'
                ? {
                    'accessToken': 'access',
                    'refreshToken': 'refresh',
                    'expiresIn': 900,
                  }
                : profile(),
          ),
          200,
        ),
      );
      late RemoteAccessService remote;
      await tester.runAsync(() async {
        remote = RemoteAccessService(
          db,
          subscription: RelaySubscription(db, client: client),
        );
        await remote.loginPlatform('test@example.com', 'fixture-only');
        await remote.refreshPlatform();
        // A saved local import, not in use.
        await remote.importPairing(
          jsonEncode({
            'outbound': {
              'type': 'vless',
              'server': 'custom.relay.test',
              'server_port': 443,
              'uuid': '11111111-1111-4111-8111-111111111111',
              'tls': {'enabled': true, 'server_name': 'custom.relay.test'},
            },
            'proxies': [
              {'name': 'smb', 'remotePort': 18445},
            ],
          }),
        );
        await remote.selectPlatform();
      });
      final config = SourceConfigurationService(sqlite3.openInMemory());
      final manager = SourceManager(
        configuration: config,
        remoteAccess: remote,
        remoteCoreValidator: (_, _) async {},
      );
      addTearDown(() async {
        await manager.dispose();
        config.close();
        db.close();
      });
      await tester.pumpWidget(
        TestApp(home: RemoteAccessSettingsPage(sources: manager)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('relay-platform-node')), findsOneWidget);
      expect(find.text('a.relay.test:443'), findsNothing);
      expect(find.byKey(const ValueKey('relay-platform-test')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('remote-connection-details')),
      );
      await tester.tap(find.byKey(const ValueKey('remote-connection-details')));
      await tester.pumpAndSettle();
      expect(find.text('a.relay.test:443'), findsOneWidget);
      expect(find.byKey(const ValueKey('relay-platform-test')), findsOneWidget);
      expect(tester.takeException(), isNull);
      // The cloud tab is in use, so it offers no switch.
      expect(find.byKey(const ValueKey('remote-enable-cloud')), findsNothing);
      // A saved local import can be switched to, after a confirmation that
      // the cloud configuration stops working.
      await tester.tap(find.text('本地导入'));
      await tester.pumpAndSettle();
      // Each mode starts with a compact overview; opening cloud details does
      // not expose local details or the destructive clear action.
      expect(find.text('custom.relay.test:443'), findsNothing);
      expect(find.byKey(const ValueKey('remote-clear')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('remote-enable-local')));
      await tester.pumpAndSettle();
      expect(find.textContaining('云端配置将失效'), findsWidgets);
      expect(remote.usePlatform, isTrue);
      await tester.tap(find.text('切换').last);
      await tester.pumpAndSettle();
      expect(remote.usePlatform, isFalse);
      expect(remote.network.outbound!['server'], 'custom.relay.test');
      // And back to the cloud side.
      await tester.tap(find.text('云端'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('remote-enable-cloud')),
      );
      await tester.tap(find.byKey(const ValueKey('remote-enable-cloud')));
      await tester.pumpAndSettle();
      expect(find.textContaining('本地导入配置将失效'), findsWidgets);
      await tester.tap(find.text('切换').last);
      await tester.pumpAndSettle();
      expect(remote.usePlatform, isTrue);
      expect(remote.network.outbound!['server'], 'a.relay.test');
      expect(tester.takeException(), isNull);
    });
  }
}
