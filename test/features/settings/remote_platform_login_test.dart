import 'dart:convert';
import 'dart:async';

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

import 'package:openplayx/features/settings/platform_login_page.dart';

import '../../app_test_host.dart';
import '../../data/remote_access/relay_subscription_test.dart' show profile;

void main() {
  testWidgets(
    'pending login shows progress, blocks duplicates, and retries in place',
    (tester) async {
      final first = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        TestApp(
          home: PlatformLoginPage(
            login: (email, password) async {
              calls++;
              if (calls == 1) await first.future;
              throw const RelayApiException('invalid_login', 401);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final field in [
        ('relay-account-email', 'owner@example.com'),
        ('relay-account-password', 'fixture-only'),
      ]) {
        await tester.enterText(
          find.descendant(
            of: find.byKey(ValueKey(field.$1)),
            matching: find.byType(EditableText),
          ),
          field.$2,
        );
      }
      final submit = find.byKey(const ValueKey('relay-login-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(submit);
      expect(calls, 1);
      first.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('登录失败，请检查账号和密码'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('relay-account-email')),
          matching: find.byType(EditableText),
        ),
        findsOneWidget,
      );
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  for (final rejected in [false, true]) {
    testWidgets(
      'login form submission reports ${rejected ? 'failure' : 'success'}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <http.Request>[];
        final db = sqlite3.openInMemory();
        final remote = RemoteAccessService(
          db,
          subscription: RelaySubscription(
            db,
            client: MockClient((req) async {
              requests.add(req);
              if (req.url.path == '/v1/auth/login') {
                return http.Response(
                  jsonEncode(
                    rejected
                        ? {
                            'error': {'code': 'invalid_login'},
                          }
                        : {
                            'accessToken': 'fixture-access',
                            'refreshToken': 'fixture-refresh',
                            'expiresIn': 900,
                          },
                  ),
                  rejected ? 401 : 200,
                );
              }
              return http.Response(jsonEncode(profile()), 200);
            }),
          ),
        );
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
        final entry = find.byKey(const ValueKey('relay-platform-login'));
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        for (final field in [
          ('relay-account-email', 'owner@example.com'),
          ('relay-account-password', 'fixture-only'),
        ]) {
          await tester.enterText(
            find.descendant(
              of: find.byKey(ValueKey(field.$1)),
              matching: find.byType(EditableText),
            ),
            field.$2,
          );
        }
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const ValueKey('relay-login-submit')));
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump(const Duration(seconds: 1));
        expect(
          requests.where((r) => r.url.path == '/v1/auth/login'),
          hasLength(1),
        );
        expect(remote.account.signedIn, !rejected);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('relay-account-password')),
          rejected ? findsOneWidget : findsNothing,
        );
        if (rejected) {
          expect(find.textContaining('登录失败，请检查账号和密码'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
