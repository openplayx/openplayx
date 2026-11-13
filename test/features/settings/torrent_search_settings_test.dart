import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final searches = <String>[];

  @override
  Future<Map<String, dynamic>> search({
    required String query,
    String category = 'all',
    String sort = 'relevance',
    int page = 1,
  }) async {
    searches.add('$query|$category|$sort|$page');
    return {
      'source_page': page,
      'page_count': 2,
      'has_next_page': page < 2,
      'result_count': 1,
      'cache': {'hit': false},
      'items': [
        {
          'result_ref': 'tsr_one',
          'title': 'ubuntu-26.04-desktop-amd64.iso',
          'size_bytes': 6517612872,
          'seeders': 118,
          'leechers': 87,
          'uploaded_date': '2026-04-25',
          'category': 'Applications > UNIX',
          'has_magnet': true,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> detail(String resultRef) async => {
    'size_bytes': 6518974464,
    'size_exact': true,
    'file_count': 1,
    'uploaded_at': '2026-04-25T16:35:39Z',
    'description': 'Plain uploader text',
    'has_magnet': true,
  };

  static const magnet =
      'magnet:?xt=urn:btih:dafc8c076ca2f3ed376eeae7c76a0d6be2415c45&dn=ubuntu';

  @override
  Future<TorrentResolution> resolve(String resultRef) async {
    if (!canResolve) throw const TorrentSearchException('service_forbidden');
    return TorrentResolution(
      serverRef: config.id,
      resultRef: resultRef,
      title: 'ubuntu',
      infoHash: 'dafc8c076ca2f3ed376eeae7c76a0d6be2415c45',
      magnet: magnet,
    );
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

  testWidgets('test search page lists candidates and detail, read-only', (
    tester,
  ) async {
    const config = TorrentSearchConfig(
      id: 'svc',
      name: 'Search',
      url: 'https://search.example.com',
    );
    final client = _FakeClient(config);
    await tester.pumpWidget(
      TestApp(
        home: TorrentSearchTryPage(config: config, client: client),
      ),
    );
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('tsearch-try-query')),
      'ubuntu',
    );
    await tap(tester, 'tsearch-try-run');
    await settle(tester);
    expect(client.searches, ['ubuntu|all|relevance|1']);
    expect(find.text('ubuntu-26.04-desktop-amd64.iso'), findsOneWidget);
    expect(find.textContaining('做种 118'), findsOneWidget);

    await tap(tester, 'tsearch-result-tsr_one');
    await settle(tester);
    expect(find.textContaining('6518974464 字节'), findsOneWidget);
    expect(find.text('Plain uploader text'), findsOneWidget);

    // The magnet is fetched only on an explicit tap, then copyable.
    expect(find.text(_FakeClient.magnet), findsNothing);
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
    await tap(tester, 'tsearch-magnet-get-tsr_one');
    await settle(tester);
    expect(find.text(_FakeClient.magnet), findsOneWidget);
    await tap(tester, 'tsearch-magnet-copy-tsr_one');
    await settle(tester);
    expect(copied, _FakeClient.magnet);
    expect(find.text('已复制 Magnet 地址'), findsOneWidget);
    // Let the confirmation snack bar go away before tapping further.
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);

    await tap(tester, 'tsearch-try-next');
    await settle(tester);
    expect(client.searches.last, 'ubuntu|all|relevance|2');
  });

  testWidgets('magnet needs the resolve scope', (tester) async {
    const config = TorrentSearchConfig(
      id: 'svc',
      name: 'Search',
      url: 'https://search.example.com',
    );
    final client = _FakeClient(config, canResolve: false);
    await tester.pumpWidget(
      TestApp(
        home: TorrentSearchTryPage(config: config, client: client),
      ),
    );
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('tsearch-try-query')),
      'ubuntu',
    );
    await tap(tester, 'tsearch-try-run');
    await settle(tester);
    await tap(tester, 'tsearch-result-tsr_one');
    await settle(tester);
    await tap(tester, 'tsearch-magnet-get-tsr_one');
    await settle(tester);
    expect(find.text('Token 没有 resolve 权限'), findsOneWidget);
    expect(find.text(_FakeClient.magnet), findsNothing);
  });
}
