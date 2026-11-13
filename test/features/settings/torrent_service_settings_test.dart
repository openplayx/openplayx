import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:openplayx/features/settings/torrent_service_settings_page.dart';
import 'package:openplayx/services/torrent/torrent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('adds a service; token goes only to secure storage', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final store = TorrentServiceStore();
    await tester.pumpWidget(
      TestApp(home: TorrentServiceSettingsPage(store: store)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('torrent-unconfigured')), findsOneWidget);
    // Nothing to add to until a service is configured.
    expect(
      tester
          .widget<ShadButton>(find.byKey(const ValueKey('torrent-add-magnet')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('torrent-add-service')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('torrent-field-url')),
      'http://bt.example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('torrent-field-token')),
      'obt_secret',
    );
    await tester.tap(find.byKey(const ValueKey('torrent-save')));
    await tester.pumpAndSettle();
    // Public plain HTTP is refused.
    expect(find.textContaining('HTTPS'), findsWidgets);
    expect(store.configs, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('torrent-field-url')),
      'https://bt.example.com/',
    );
    await tester.tap(find.byKey(const ValueKey('torrent-save')));
    // The list refreshes against the (mocked) network afterwards; its
    // progress indicator keeps animating, so pump a bounded time.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(store.configs.single.baseUrl, 'https://bt.example.com');
    expect(await store.hasToken(store.configs.single.id), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('openplayx.torrent.services.v1'),
      isNot(contains('obt_secret')),
    );
    expect(
      find.byKey(ValueKey('torrent-service-${store.configs.single.id}')),
      findsOneWidget,
    );
    // Let the post-save refresh (mocked network) finish so the page is idle.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    // Add Magnet: a non-magnet text is refused before reaching the server.
    await tester.tap(find.byKey(const ValueKey('torrent-add-magnet')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('torrent-magnet-input')), findsOneWidget);
    expect(find.text('只下载视频文件'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('torrent-magnet-input')),
      'http://example.com/a.torrent',
    );
    await tester.tap(find.byKey(const ValueKey('torrent-magnet-preview')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('请粘贴以 magnet:? 开头的链接'), findsOneWidget);
    // Unmount to stop the page's polling timer.
    await tester.pumpWidget(const SizedBox());
  });
}
