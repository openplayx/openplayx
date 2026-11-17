import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/sources/dlna_source.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/features/sources/view/source_instance_form.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'source_flow_test.dart' show MemorySources;

Future<void> openForm(
  WidgetTester tester,
  MemorySources sources, {
  Future<List<DlnaDevice>> Function()? discover,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1400);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    TestApp(
      home: Builder(
        builder: (context) => Center(
          child: ShadButton(
            onPressed: () => Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => SourceInstanceForm(
                  manager: sources,
                  discoverDlna: discover,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> chooseKind(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('source-kind')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every source kind is offered with its own icon', (tester) async {
    await openForm(tester, MemorySources());
    await tester.tap(find.byKey(const ValueKey('source-kind')));
    await tester.pumpAndSettle();
    for (final label in [
      'SMB',
      'WebDAV',
      'OneDrive',
      'Dropbox',
      'FTP',
      'SFTP',
      'S3',
      'Plex',
      'Jellyfin',
      'Emby',
      'DLNA',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });

  testWidgets('WebDAV saves address, username and password', (tester) async {
    final sources = MemorySources();
    await openForm(tester, sources);
    await chooseKind(tester, 'WebDAV');
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(1), 'https://dav.example.com/remote');
    await tester.enterText(fields.at(2), 'viewer');
    await tester.enterText(fields.at(3), 'secret');
    expect(find.text('匿名访问时，用户名和密码都留空'), findsOneWidget);
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    final saved = sources.saved.single;
    expect(saved.kind, SourceKind.webdav);
    expect(saved.address, 'https://dav.example.com/remote');
    expect(saved.username, 'viewer');
    expect(sources.secrets.single, 'secret');
  });

  testWidgets('Jianguoyun preset keeps WebDAV protocol and default folder', (
    tester,
  ) async {
    final sources = MemorySources();
    await openForm(tester, sources);
    await chooseKind(tester, 'WebDAV');
    await tester.tap(find.text('自定义 WebDAV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('坚果云').last);
    await tester.pumpAndSettle();
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(2), 'account@example.com');
    await tester.enterText(fields.at(3), 'app-password');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    final saved = sources.saved.single;
    expect(saved.kind, SourceKind.webdav);
    expect(saved.presetId, 'jianguoyun');
    expect(saved.address, 'https://dav.jianguoyun.com/dav');
    expect(saved.typeLabel, '坚果云');
  });

  testWidgets(
    '123 preset leaves endpoint empty and explains account entitlement',
    (tester) async {
      await openForm(tester, MemorySources());
      await chooseKind(tester, 'WebDAV');
      await tester.tap(find.text('自定义 WebDAV'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('123 云盘').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).at(1))
            .controller
            .text,
        isEmpty,
      );
      expect(find.textContaining('WebDAV 权益'), findsOneWidget);
    },
  );

  testWidgets(
    'cloud form offers browser sign-in without developer key or password fields',
    (tester) async {
      await openForm(tester, MemorySources());
      await chooseKind(tester, 'OneDrive');
      expect(find.text('使用浏览器登录'), findsOneWidget);
      expect(
        find.byType(EditableText),
        findsOneWidget,
      ); // optional instance name
      expect(
        tester
            .widget<ShadButton>(find.byKey(const ValueKey('source-save')))
            .enabled,
        isFalse,
      );
    },
  );

  testWidgets('S3 shows key, region and bucket fields', (tester) async {
    final sources = MemorySources();
    await openForm(tester, sources);
    await chooseKind(tester, 'S3');
    expect(find.text('Access Key ID'), findsOneWidget);
    expect(find.text('Secret Access Key'), findsOneWidget);
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(1), 'http://minio.lan:9000');
    await tester.enterText(fields.at(2), 'key');
    await tester.enterText(fields.at(3), 'secret');
    await tester.enterText(fields.at(4), 'eu-west-1');
    await tester.enterText(fields.at(5), 'media/movies');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    final saved = sources.saved.single;
    expect(saved.address, 'http://minio.lan:9000/media/movies');
    expect(saved.domain, 'eu-west-1');
    expect(saved.rootPath, '/media/movies');
  });

  testWidgets('DLNA picks a discovered device', (tester) async {
    final sources = MemorySources();
    await openForm(
      tester,
      sources,
      discover: () async => [
        DlnaDevice('客厅 NAS', Uri.parse('http://192.168.1.5:8200/rootDesc.xml')),
      ],
    );
    await chooseKind(tester, 'DLNA');
    await tester.tap(find.text('搜索局域网设备'));
    await tester.pumpAndSettle();
    expect(find.text('客厅 NAS'), findsWidgets); // row + name hint
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    final saved = sources.saved.single;
    expect(saved.kind, SourceKind.dlna);
    expect(saved.name, '客厅 NAS');
    expect(saved.address, 'http://192.168.1.5:8200/rootDesc.xml');
    expect(sources.secrets.single, '');
  });
}
