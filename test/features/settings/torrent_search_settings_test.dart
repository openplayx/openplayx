import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/features/settings/torrent_search_settings_page.dart';
import 'package:openplayx/services/torrent_search/torrent_search_client.dart';
import 'package:openplayx/services/torrent_search/torrent_search_config.dart';
import 'package:sqlite3/sqlite3.dart';

class _FakeClient extends TorrentSearchClient {
  _FakeClient(TorrentSearchConfig config, {this.canResolve = true})
    : super(config: config, token: () async => 'x');
  final bool canResolve;

  @override
  Future<Map<String, dynamic>> capabilities() async {
    return {
      'operations': {'search': true, 'resolve': canResolve},
    };
  }

  @override
  Future<Map<String, dynamic>> categories() async => {
    'categories': [
      {'key': 'all'},
      {'key': 'video'},
    ],
  };
}

void main() {
  late Database db;
  late TorrentSearchRegistry registry;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = sqlite3.openInMemory();
    registry = TorrentSearchRegistry(db: db);
  });
  tearDown(() => db.close());

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('adds a LAN service; token only in secure storage', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: TorrentSearchSettingsPage(
          registry: registry,
          clientFor: (c) => _FakeClient(c),
        ),
      ),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('tsearch-unconfigured')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tsearch-add-service')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('tsearch-field-url')),
      'http://192.168.1.211:18790',
    );
    await tester.enterText(
      find.byKey(const ValueKey('tsearch-field-token')),
      'secret-token-value',
    );
    await tester.tap(find.byKey(const ValueKey('tsearch-save')));
    await settle(tester);
    // Plain HTTP needs the explicit LAN switch.
    expect(find.textContaining('局域网 HTTP'), findsOneWidget);
    expect(registry.list(), isEmpty);

    await tap(tester, 'tsearch-allow-http');
    await tester.tap(find.byKey(const ValueKey('tsearch-save')));
    await settle(tester);
    final saved = registry.list().single;
    expect(saved.url, 'http://192.168.1.211:18790');
    expect(saved.allowInsecureHttp, isTrue);
    expect(await registry.credential(saved), 'secret-token-value');
    expect(
      db.select('SELECT * FROM torrent_search_services').toString(),
      isNot(contains('secret-token-value')),
    );
    // Back on the list: the service and its live status are shown.
    expect(find.byKey(ValueKey('tsearch-service-${saved.id}')), findsOneWidget);
    expect(find.textContaining('可交给下载服务'), findsOneWidget);
  });

  testWidgets('public HTTP is refused even with the LAN switch', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(home: TorrentSearchForm(registry: registry)),
    );
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('tsearch-field-url')),
      'http://search.example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('tsearch-field-token')),
      'secret-token-value',
    );
    await tap(tester, 'tsearch-allow-http');
    await tester.tap(find.byKey(const ValueKey('tsearch-save')));
    await settle(tester);
    expect(find.textContaining('公网地址必须使用 HTTPS'), findsOneWidget);
    expect(registry.list(), isEmpty);
  });

  testWidgets('test connection checks scopes and the default category', (
    tester,
  ) async {
    final config = registry.save(
      const TorrentSearchConfig(
        id: 'svc',
        name: 'Search',
        url: 'https://search.example.com',
        defaultCategory: 'video.hd_movies',
      ),
    );
    await registry.setCredential(config, 'secret-token-value');
    await tester.pumpWidget(
      TestApp(
        home: TorrentSearchForm(
          registry: registry,
          config: config,
          clientFor: (c) => _FakeClient(c, canResolve: false),
        ),
      ),
    );
    await settle(tester);
    await tap(tester, 'tsearch-test');
    await settle(tester);
    expect(find.textContaining('不支持默认分类'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('tsearch-field-category')),
      'video',
    );
    await tap(tester, 'tsearch-test');
    await settle(tester);
    expect(find.textContaining('没有 resolve 权限'), findsOneWidget);
    // Token left empty keeps the saved one.
    expect(
      await registry.credential(registry.get('svc')!),
      'secret-token-value',
    );
    expect(registry.get('svc')!.defaultCategory, 'video');
  });
}
