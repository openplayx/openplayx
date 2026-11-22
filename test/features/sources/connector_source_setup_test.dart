import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/data/remote_access/discovered_source.dart';
import 'package:openplayx/data/remote_access/remote_access_service.dart';
import 'package:openplayx/data/remote_access/remote_config.dart';
import 'package:openplayx/features/sources/view/source_page.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../app_test_host.dart';
import 'source_flow_test.dart' show MemorySources;

class DiscoveredSources extends MemorySources {
  @override
  List<DiscoveredSource> get discoveredSources => const [
    DiscoveredSource(
      accountId: 'user_a',
      connectorId: 'connector_a',
      serviceId: 'service_a',
      name: '家庭 NAS',
      connectorName: '家庭 Connector',
      type: 'smb',
      status: 'enabled',
    ),
  ];
}

void main() {
  testWidgets(
    'discovered NAS goes straight to login and explicit scope without choosing a remote service',
    (tester) async {
      final sources = DiscoveredSources()
        ..network = const RemoteNetwork(
          outbound: {
            'type': 'vless',
            'server': 'relay.example',
            'server_port': 443,
            'tls': {'enabled': true, 'server_name': 'relay.example'},
          },
          credential: {'uuid': '11111111-1111-4111-8111-111111111111'},
          proxies: [RemoteProxy('service_a', 18000)],
        );
      final library = LibraryService(sqlite3.openInMemory());
      addTearDown(library.close);
      await tester.pumpWidget(
        TestApp(
          home: SourcePage(manager: sources, library: library),
        ),
      );
      await tester.pumpAndSettle();
      expect(sources.saved, isEmpty);
      expect(find.text('家庭 NAS'), findsOneWidget);
      await tester.tap(find.text('家庭 NAS'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('remote-proxy')), findsNothing);
      expect(find.byKey(const ValueKey('source-kind')), findsNothing);
      expect(find.byKey(const ValueKey('地址')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('用户名')), 'viewer');
      await tester.enterText(find.byKey(const ValueKey('密码')), 'password');
      await tester.ensureVisible(find.byKey(const ValueKey('source-save')));
      await tester.tap(find.byKey(const ValueKey('source-save')));
      await tester.pumpAndSettle();
      expect(sources.saved, hasLength(1));
      expect(sources.saved.single.remote!.proxy, 'service_a');
      expect(sources.saved.single.remote!.accountId, 'user_a');
      expect(library.fileSourceList(), isEmpty);
      await tester.tap(find.text('Videos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加并显示到首页'));
      await tester.pumpAndSettle();
      expect(library.fileSourceList(), hasLength(1));
      expect(library.fileSourceList().single.root, 'folder');
      expect(sources.pendingDiscoveredSources, isEmpty);
      expect(find.byKey(const ValueKey('discovered-service_a')), findsNothing);
    },
  );
}
