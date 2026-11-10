import '../../app_test_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/library/library_page.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:sqlite3/sqlite3.dart';

class ServerSources extends SourceManager {
  final browsed = <String?>[];
  @override
  List<SourceConfig> get configs => const [
    SourceConfig(
      id: 'jf',
      kind: SourceKind.jellyfin,
      name: '家庭影院',
      address: 'http://jf.lan:8096',
      userId: 'u',
    ),
    SourceConfig(
      id: 'nas',
      kind: SourceKind.smb,
      name: 'NAS',
      address: 'smb://nas/share',
    ),
  ];
  @override
  Future<void> load() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<List<SourceEntry>> featured(String id, {int limit = 20}) async => [
    const SourceEntry(ResourceRef('jf', 'series-1'), '新剧', isFolder: true),
    const SourceEntry(ResourceRef('jf', 'movie-1'), '新电影', isFolder: false),
  ];
  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) async {
    browsed.add(request.node?.id);
    return BrowseResult([
      if (request.node == null)
        const SourceEntry(ResourceRef('jf', 'lib-movies'), '电影', isFolder: true)
      else
        const SourceEntry(ResourceRef('jf', 'ep-1'), '第 1 集', isFolder: false),
    ]);
  }

  @override
  Future<PlayableStream> resolve(ResourceRef resource) async =>
      PlayableStream(Uri.parse('http://127.0.0.1:1/${resource.id}'));
}

void main() {
  testWidgets('media servers get shelves above the local wall', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final service = LibraryService(sqlite3.openInMemory());
    addTearDown(service.close);
    final sources = ServerSources();
    final played = <SourceSelection>[];
    await tester.pumpWidget(
      TestApp(
        home: LibraryPage(
          sources: sources,
          service: service,
          onPlay: played.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Only the media server gets a shelf; the SMB share feeds the wall.
    expect(find.text('家庭影院'), findsOneWidget);
    expect(find.text('NAS'), findsNothing);
    expect(find.text('本地媒体库'), findsOneWidget);
    expect(find.text('新剧'), findsOneWidget);
    // A file plays straight from the shelf.
    await tester.tap(find.text('新电影'));
    await tester.pumpAndSettle();
    expect(played.single.ref?.id, 'movie-1');
    expect(played.single.entry?.name, '新电影');
    // A folder opens its poster wall.
    await tester.tap(find.text('新剧'));
    await tester.pumpAndSettle();
    expect(sources.browsed.last, 'series-1');
    await tester.tap(find.text('第 1 集'));
    await tester.pumpAndSettle();
    expect(played.last.ref?.id, 'ep-1');
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    // "All" lists the server's libraries.
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(sources.browsed.last, isNull);
    expect(find.text('电影'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
