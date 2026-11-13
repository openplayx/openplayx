import 'dart:convert';
import 'dart:io';

import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/features/settings/torrent_service_settings_page.dart';
import 'package:openplayx/services/torrent/torrent_service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal bittorrent-server: one torrent; records remove-plan choices.
Future<(HttpServer, List<String>)> fakeServer() async {
  final log = <String>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final id = 'a' * 40;
  server.listen((req) async {
    final body = await utf8.decoder.bind(req).join();
    final path = '${req.method} ${req.uri.path}';
    Object out;
    switch (path) {
      case 'GET /api/v1/capabilities':
        out = {
          'engine': {'available': true, 'version': 'v5.1.0'},
        };
      case 'GET /api/v1/torrents':
        out = {
          'items': [
            {
              'id': id,
              'name': 'Sample',
              'state': 'seeding',
              'progress': 1.0,
              'added_via': 'app',
            },
          ],
        };
      default:
        if (path == 'POST /api/v1/torrents/$id/remove-plan') {
          final del = (jsonDecode(body) as Map)['delete_files'] == true;
          log.add('plan delete_files=$del');
          out = {
            'plan_ref': 'rm.$del',
            'task_name': 'Sample',
            'files_on_disk': 1,
            'bytes_on_disk': 2 << 30,
          };
        } else if (path == 'POST /api/v1/torrents/$id/remove') {
          final ref = (jsonDecode(body) as Map)['plan_ref'];
          log.add('remove $ref');
          out = {
            'task_id': id,
            'removed': true,
            'data_deleted': ref == 'rm.true',
          };
        } else {
          out = {};
        }
    }
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(out));
    await req.response.close();
  });
  return (server, log);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final allow in [false, true]) {
    testWidgets('remove dialog, delete files allowed=$allow', (tester) async {
      HttpOverrides.global = null; // real loopback HTTP for the fake server
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final (server, log) = (await tester.runAsync(fakeServer))!;
      addTearDown(() => server.close(force: true));
      final store = TorrentServiceStore();
      await tester.runAsync(() async {
        await store.load();
        await store.save(
          TorrentServiceConfig(
            id: 'bt-1',
            name: 'Home',
            baseUrl: 'http://127.0.0.1:${server.port}',
            allowDeleteFiles: allow,
          ),
          token: 't',
        );
      });
      await tester.pumpWidget(
        TestApp(home: TorrentServiceSettingsPage(store: store)),
      );
      await settle(tester);
      expect(find.text('Sample'), findsOneWidget);

      await tester.tap(find.text('移除'));
      await settle(tester);
      final box = find.byKey(const ValueKey('torrent-remove-delete-files'));
      expect(box, findsOneWidget);
      expect(find.textContaining('同时删除已下载的文件'), findsOneWidget);
      expect(tester.widget<ShadCheckbox>(box).enabled, allow);
      if (allow) {
        await tester.tap(box);
        await tester.pump();
        expect(
          find.text('删除'),
          findsOneWidget,
        ); // destructive label once ticked
        expect(find.textContaining('不可恢复'), findsOneWidget);
      } else {
        expect(find.textContaining('允许删除服务器文件'), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('torrent-remove-confirm')));
      await settle(tester);
      expect(
        log,
        allow
            ? [
                'plan delete_files=false',
                'plan delete_files=true',
                'remove rm.true',
              ]
            : ['plan delete_files=false', 'remove rm.false'],
      );
      await settle(tester); // response + list refresh
      expect(find.text(allow ? '已移除并删除文件。' : '已移除，文件保留在服务器上。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      // Let request timeout timers (fake clock) expire.
      await tester.pump(const Duration(seconds: 30));
    });
  }
}
