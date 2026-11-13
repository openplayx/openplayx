import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
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
    // Unmount to stop the page's polling timer.
    await tester.pumpWidget(const SizedBox());
  });
}
