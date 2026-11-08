import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/player/player_page.dart';

import '../player/player_page_test.dart' show FakeBackend;

class MemorySources extends SourceManager {
  final saved = <SourceConfig>[];
  final secrets = <String>[];
  bool failBrowse = false;
  int releases = 0;
  @override
  List<SourceConfig> get configs => List.unmodifiable(saved);
  @override
  Future<void> load() async {}
  @override
  Future<void> save(SourceConfig config, String secret) async {
    config.validate();
    saved.removeWhere((c) => c.id == config.id);
    saved.add(config);
    secrets.add(secret);
  }

  @override
  Future<void> remove(String id) async => saved.removeWhere((c) => c.id == id);
  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) async {
    if (failBrowse) {
      throw const PluginException('networkUnavailable', '测试服务不可用');
    }
    if (request.node == null) {
      return BrowseResult([
        SourceEntry(ResourceRef(id, 'folder'), 'Videos', isFolder: true),
      ]);
    }
    return BrowseResult([
      SourceEntry(ResourceRef(id, 'video'), 'Demo.mp4', isFolder: false),
    ]);
  }

  @override
  Future<PlayableStream> resolve(ResourceRef resource) async => PlayableStream(
    Uri.parse('http://127.0.0.1:18000/session'),
    release: () async {
      releases++;
    },
  );
}

void main() {
  testWidgets(
    'configure SMB, edit it, recover browse failure and play selected file',
    (tester) async {
      final sources = MemorySources();
      final backend = FakeBackend();
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerPage(backend: backend, sourceManager: sources),
        ),
      );
      await tester.tap(find.text('媒体源'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加源'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<SourceKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SMB').last);
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'NAS');
      await tester.enterText(fields.at(1), 'smb://localhost/media');
      await tester.enterText(fields.at(2), 'viewer');
      await tester.enterText(fields.at(4), 'password');
      expect(tester.widget<TextField>(fields.at(4)).obscureText, isTrue);
      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(sources.saved.single.kind, SourceKind.smb);
      expect(sources.secrets.single, 'password');
      await tester.tap(find.byTooltip('编辑媒体源'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Living Room NAS');
      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      sources.failBrowse = true;
      await tester.tap(find.text('Living Room NAS'));
      await tester.pumpAndSettle();
      expect(find.text('测试服务不可用'), findsOneWidget);
      sources.failBrowse = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Videos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo.mp4'));
      await tester.pumpAndSettle();
      expect(
        backend.opened.single,
        Uri.parse('http://127.0.0.1:18000/session'),
      );
      expect(find.text('Demo.mp4'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(sources.releases, 1);
    },
  );

  testWidgets(
    'delete configuration requires confirmation and cancellation preserves it',
    (tester) async {
      final sources = MemorySources()
        ..saved.add(
          const SourceConfig(
            id: 'nas',
            kind: SourceKind.smb,
            name: 'NAS',
            address: 'smb://localhost/media',
          ),
        );
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerPage(backend: FakeBackend(), sourceManager: sources),
        ),
      );
      await tester.tap(find.text('媒体源'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('删除媒体源'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(sources.saved, hasLength(1));
      await tester.tap(find.byTooltip('删除媒体源'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(sources.saved, isEmpty);
    },
  );
}
