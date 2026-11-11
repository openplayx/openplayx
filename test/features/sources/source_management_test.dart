import '../../app_test_host.dart';

import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/sources/source_page.dart';
import 'package:openplayx/features/sources/source_instance_form.dart';
import 'package:openplayx/data/sources/source_sign_in.dart';

import 'source_flow_test.dart' show MemorySources;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  testWidgets(
    'narrow source management shows version, confirms disable and preserves credentials',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final service = SourceConfigurationService(sqlite3.openInMemory());
      final manager = SourceManager(configuration: service);
      await manager.save(
        const SourceConfig(
          id: 'plex',
          kind: SourceKind.plex,
          name: 'Living Room',
          address: 'http://localhost:32400',
        ),
        'safe-token',
      );
      await manager.setDefault('source.browse', 'plex');
      addTearDown(() async {
        await manager.dispose();
        service.close();
      });
      await tester.pumpWidget(TestApp(home: SourcePage(manager: manager)));
      await tester.pumpAndSettle();
      expect(find.textContaining('配置 v2'), findsOneWidget);
      expect(find.textContaining('尚未验证'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(ShadSwitch));
      await tester.tap(find.byType(ShadSwitch));
      await tester.pumpAndSettle();
      expect(find.text('禁用媒体源？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(manager.configs.single.enabled, isTrue);
      await tester.ensureVisible(find.byType(ShadSwitch));
      await tester.tap(find.byType(ShadSwitch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('禁用'));
      await tester.pumpAndSettle();
      expect(manager.configs.single.enabled, isFalse);
      expect(manager.bindings.defaults, isEmpty);
      expect(service.readSecret('source.plex'), isNull);
      expect(
        service.readSecret(manager.configs.single.credentialRef!),
        'safe-token',
      );
      expect(find.text('已禁用'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'connection forms keep basic fields simple and hide management policies',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final service = SourceConfigurationService(sqlite3.openInMemory());
      final manager = SourceManager(configuration: service);
      addTearDown(() async {
        await manager.dispose();
        service.close();
      });
      await tester.pumpWidget(
        TestApp(
          home: Scaffold(body: SourceInstanceForm(manager: manager)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('选择文件夹'), findsOneWidget);
      expect(find.byType(EditableText), findsOneWidget);
      expect(find.textContaining('修订'), findsNothing);
      expect(find.text('实例与连接策略'), findsNothing);
      expect(find.text('目录范围与扫描策略'), findsNothing);
      await tester.tap(find.byType(ShadSelect<SourceKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jellyfin').last);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('地址')), findsOneWidget);
      expect(find.byKey(ValueKey('用户名')), findsOneWidget);
      expect(find.byKey(ValueKey('密码')), findsOneWidget);
      expect(find.textContaining('用户 ID'), findsNothing);
      expect(find.textContaining('API Key'), findsNothing);
      expect(find.byKey(ValueKey('端口')), findsNothing);
      await tester.tap(find.text('高级'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('端口')), findsOneWidget);
      expect(find.byKey(ValueKey('路径（可选）')), findsOneWidget);
      await tester.tap(find.byType(ShadSelect<SourceKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plex').last);
      await tester.pumpAndSettle();
      expect(find.text('登录 Plex'), findsOneWidget);
      expect(find.text('X-Plex-Token'), findsNothing);
      expect(find.byType(EditableText), findsOneWidget);
    },
  );
  testWidgets(
    'pasted server URL fills advanced values and editing preserves hidden policies',
    (tester) async {
      final manager = MemorySources();
      const config = SourceConfig(
        id: 'j',
        kind: SourceKind.jellyfin,
        name: 'Jellyfin',
        address: 'http://old.test:8096',
        username: 'viewer',
        userId: 'old-user',
        requestTimeoutSeconds: 47,
        maxConcurrentRequests: 4,
        logicalSourceId: 'keep-binding',
      );
      manager.saved.add(config);
      final signIn = _FakeSignIn();
      addTearDown(signIn.close);
      await tester.pumpWidget(
        TestApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => SourceInstanceForm(
                    manager: manager,
                    initial: config,
                    signIn: signIn,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(ValueKey('地址')),
        'https://new.test:8443/jellyfin',
      );
      await tester.tap(find.text('高级'));
      await tester.pumpAndSettle();
      expect(tester.widget<ShadSwitch>(find.byType(ShadSwitch)).value, isTrue);
      expect(
        tester.widget<ShadInput>(find.byKey(ValueKey('端口'))).controller!.text,
        '8443',
      );
      expect(
        tester
            .widget<ShadInput>(find.byKey(ValueKey('路径（可选）')))
            .controller!
            .text,
        'jellyfin',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(manager.saved.single.address, 'https://new.test:8443/jellyfin');
      expect(manager.saved.single.requestTimeoutSeconds, 47);
      expect(manager.saved.single.maxConcurrentRequests, 4);
      expect(manager.saved.single.logicalSourceId, 'keep-binding');
    },
  );
  testWidgets(
    'Jellyfin resolves the user ID and saves only the session token',
    (tester) async {
      final manager = MemorySources();
      final signIn = _FakeSignIn();
      addTearDown(signIn.close);
      await tester.pumpWidget(
        TestApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) =>
                      SourceInstanceForm(manager: manager, signIn: signIn),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ShadSelect<SourceKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jellyfin').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(ValueKey('地址')), '192.168.1.20');
      await tester.enterText(find.byKey(ValueKey('用户名')), 'viewer');
      await tester.enterText(find.byKey(ValueKey('密码')), 'user-password');
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      expect(manager.saved.single.address, 'http://192.168.1.20:8096');
      expect(manager.saved.single.userId, 'automatic-user-id');
      expect(manager.saved.single.name, isEmpty);
      expect(
        manager.saved.single.displayName,
        'Jellyfin · http://192.168.1.20:8096',
      );
      expect(manager.secrets.single, 'automatic-session-token');
      expect(signIn.password, 'user-password');
    },
  );
  testWidgets(
    'manual Plex connection requests a token instead of sending users to account login',
    (tester) async {
      final manager = MemorySources();
      await tester.pumpWidget(
        TestApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => SourceInstanceForm(manager: manager),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ShadSelect<SourceKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plex').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('高级'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(ShadSwitch));
      await tester.tap(find.byType(ShadSwitch));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(ValueKey('服务器地址')),
        'http://192.168.1.211:13240',
      );
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      expect(find.text('请填写访问令牌后连接服务器。'), findsOneWidget);
      expect(find.text('请先登录 Plex 并选择服务器。'), findsNothing);
      await tester.enterText(find.byKey(ValueKey('访问令牌')), 'test-token');
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      expect(manager.saved.single.address, 'http://192.168.1.211:13240');
      expect(manager.secrets.single, 'test-token');
    },
  );
  testWidgets(
    'Plex opens official login then saves the selected server token',
    (tester) async {
      final manager = MemorySources();
      final signIn = _FakeSignIn();
      addTearDown(signIn.close);
      Uri? opened;
      await tester.pumpWidget(
        TestApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => SourceInstanceForm(
                    manager: manager,
                    signIn: signIn,
                    openBrowser: (uri) async {
                      opened = uri;
                      return true;
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ShadSelect<SourceKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plex').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('登录 Plex'));
      await tester.pumpAndSettle();
      expect(opened?.host, 'app.plex.tv');
      expect(find.text('Home Plex'), findsOneWidget);
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      expect(manager.saved.single.name, 'Home Plex');
      expect(manager.saved.single.address, 'http://127.0.0.1:32400');
      expect(manager.secrets.single, 'selected-server-token');
    },
  );
  testWidgets('local source chooses a folder and generates its display name', (
    tester,
  ) async {
    final manager = MemorySources();
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => SourceInstanceForm(
                  manager: manager,
                  chooseDirectory: () async => '/tmp/Movies',
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择文件夹'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(manager.saved.single.address, '/tmp/Movies');
    expect(manager.saved.single.name, isEmpty);
    expect(manager.saved.single.displayName, '本地文件夹 · /tmp/Movies');
  });
}

class _FakeSignIn extends SourceSignIn {
  String? password;
  @override
  Future<JellyfinSession> jellyfin(SourceConfig config, String value) async {
    password = value;
    return const JellyfinSession(
      'automatic-user-id',
      'automatic-session-token',
    );
  }

  @override
  Future<PlexPin> startPlex(String id) async => PlexPin(
    1,
    'pin',
    DateTime.now().add(const Duration(minutes: 5)),
    Uri.parse('https://app.plex.tv/auth#?code=pin'),
  );
  @override
  Future<String?> pollPlex(String id, PlexPin pin) async => 'account-token';
  @override
  Future<List<PlexServer>> plexServers(String id, String token) async => [
    PlexServer(
      id: 'home',
      name: 'Home Plex',
      token: 'selected-server-token',
      connections: [Uri.parse('http://127.0.0.1:32400')],
    ),
  ];
  @override
  Future<Uri> connectPlex(String id, PlexServer server) async =>
      server.connections.single;
}
