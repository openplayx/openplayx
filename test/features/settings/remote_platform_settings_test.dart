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
      });
      final config = SourceConfigurationService(sqlite3.openInMemory());
      final manager = SourceManager(
        configuration: config,
        remoteAccess: remote,
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
      expect(find.text('a.relay.test:443'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('relay-platform-restore')),
      );
      await tester.tap(find.byKey(const ValueKey('relay-platform-restore')));
      await tester.pumpAndSettle();
      expect(remote.usePlatform, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
