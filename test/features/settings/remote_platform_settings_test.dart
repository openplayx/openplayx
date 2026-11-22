import 'dart:convert';

import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  testWidgets('registration finishes in the App and then opens sign-in', (
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
          if (req.url.path == '/v1/auth/registration/complete') {
            final code = jsonDecode(req.body)['code'];
            return code == '123456'
                ? http.Response(
                    '{"status":"registered","email":"owner@example.com"}',
                    200,
                  )
                : http.Response('{"error":{"code":"invalid_code"}}', 400);
          }
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
    Finder field(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(EditableText),
    );
    Future<void> settle() async {
      for (var i = 0; i < 2; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

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
      field('relay-registration-email'),
      'owner@example.com',
    );
    final typed = tester.widget<EditableText>(
      field('relay-registration-email'),
    );
    expect(typed.autofillHints, contains(AutofillHints.username));
    expect(typed.readOnly, isFalse);
    final typedState = tester.state(field('relay-registration-email'));
    await tester.tap(find.byKey(const ValueKey('relay-registration-submit')));
    await settle();
    expect(requests.single.url.path, '/v1/auth/registration/request');
    expect(jsonDecode(requests.single.body), {'email': 'owner@example.com'});
    expect(find.byKey(const ValueKey('relay-registration-code')), findsOne);

    // The email rides along for the system password manager.
    final account = tester.widget<EditableText>(
      field('relay-registration-email'),
    );
    expect(account.controller.text, 'owner@example.com');
    expect(account.readOnly, isTrue);
    // The same field the user typed into, not a new one.
    expect(tester.state(field('relay-registration-email')), same(typedState));
    expect(account.autofillHints, contains(AutofillHints.username));
    final password = tester.widget<EditableText>(
      field('relay-registration-password'),
    );
    expect(password.autofillHints, [AutofillHints.newPassword]);
    expect(password.obscureText, isTrue);

    // A suggested strong password lands in both fields at once.
    await tester.enterText(field('relay-registration-code'), '123456');
    await tester.enterText(
      field('relay-registration-password'),
      'owner-password-123',
    );
    await tester.pump();
    // Fields reach the platform top to bottom, so password managers find the
    // account right before the password.
    final setClient = tester.testTextInput.log.lastWhere(
      (call) => call.method == 'TextInput.setClient',
    );
    final client = (setClient.arguments as List)[1] as Map;
    final fields = [
      for (final f in client['fields'] as List) (f as Map)['autofill'] as Map,
    ];
    expect(
      [for (final f in fields) (f['hints'] as List).first],
      [
        AutofillHints.username,
        AutofillHints.oneTimeCode,
        AutofillHints.newPassword,
        AutofillHints.newPassword,
      ],
    );
    int javaHash(String s) =>
        s.codeUnits.fold(0, (h, c) => (h * 31 + c).toSigned(32));
    final hashes = [for (final f in fields) javaHash(f['uniqueIdentifier'])];
    expect(hashes, [...hashes]..sort());
    expect(
      (client['autofill'] as Map)['uniqueIdentifier'],
      fields[2]['uniqueIdentifier'],
    );
    expect(
      tester
          .widget<EditableText>(field('relay-registration-confirm'))
          .controller
          .text,
      'owner-password-123',
    );

    // The eye reveals the password; only then can it be copied.
    final passwordField = find.byKey(
      const ValueKey('relay-registration-password'),
    );
    Finder inPassword(String key) =>
        find.descendant(of: passwordField, matching: find.byKey(ValueKey(key)));
    expect(inPassword('secret-input-copy'), findsNothing);
    await tester.tap(inPassword('secret-input-reveal'));
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(field('relay-registration-password'))
          .obscureText,
      isFalse,
    );
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(inPassword('secret-input-copy'));
    await tester.pump(const Duration(seconds: 1));
    expect(copied, 'owner-password-123');

    // A mismatched confirmation never reaches the API.
    await tester.enterText(field('relay-registration-confirm'), 'different');
    await tester.tap(find.byKey(const ValueKey('relay-registration-complete')));
    await settle();
    expect(requests, hasLength(1));

    // A wrong code keeps the user on the code step.
    await tester.enterText(field('relay-registration-code'), '654321');
    await tester.enterText(
      field('relay-registration-confirm'),
      'owner-password-123',
    );
    await tester.tap(find.byKey(const ValueKey('relay-registration-complete')));
    await settle();
    expect(requests, hasLength(2));
    expect(find.byKey(const ValueKey('relay-registration-code')), findsOne);

    await tester.enterText(field('relay-registration-code'), '123456');
    await tester.tap(find.byKey(const ValueKey('relay-registration-complete')));
    await settle();
    await tester.pump(const Duration(seconds: 1));
    expect(requests.last.url.path, '/v1/auth/registration/complete');
    expect(jsonDecode(requests.last.body), {
      'email': 'owner@example.com',
      'code': '123456',
      'password': 'owner-password-123',
    });
    // Registration does not sign in; the sign-in page opens prefilled.
    expect(remote.account.signedIn, isFalse);
    expect(find.byKey(const ValueKey('relay-login-submit')), findsOne);
    expect(
      tester.widget<EditableText>(field('relay-account-email')).controller.text,
      'owner@example.com',
    );
    // Let the resend cooldown timer of the popped page finish.
    await tester.pump(const Duration(seconds: 61));
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
