import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/data/sources/dlna_source.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/features/sources/source_instance_form.dart';
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
            onPressed: () => showShadDialog<bool>(
              context: context,
              builder: (_) => SourceInstanceForm(
                manager: sources,
                discoverDlna: discover,
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
  await tester.tap(find.byType(ShadSelect<SourceKind>));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every source kind is offered with its own icon', (tester) async {
    await openForm(tester, MemorySources());
    await tester.tap(find.byType(ShadSelect<SourceKind>));
    await tester.pumpAndSettle();
    for (final label in [
      'SMB',
      'WebDAV',
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
    expect(find.text('客厅 NAS'), findsOneWidget);
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    final saved = sources.saved.single;
    expect(saved.kind, SourceKind.dlna);
    expect(saved.name, '客厅 NAS');
    expect(saved.address, 'http://192.168.1.5:8200/rootDesc.xml');
    expect(sources.secrets.single, '');
  });
}
