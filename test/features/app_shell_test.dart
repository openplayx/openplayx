import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app_shell.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx_playback/playback.dart';

import 'library/library_page_test.dart' show Sources;
import 'player/player_page_test.dart' show FakeBackend;

class ShellSources extends Sources {
  int releases = 0;
  @override
  Future<PlayableStream> resolve(ResourceRef ref) async => PlayableStream(
    Uri.parse('https://example.test/video.mp4'),
    release: () async {
      releases++;
    },
  );
}

void main() {
  testWidgets(
    'responsive navigation retains library selection and source category',
    (tester) async {
      final service = LibraryService(sqlite3.openInMemory());
      service.create('Movies');
      final backend = FakeBackend();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            library: service,
            sources: ShellSources(),
            backend: backend,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('继续观看'), findsOneWidget);
      expect(find.text('最近播放'), findsOneWidget);
      await tester.tap(find.text('媒体库').first);
      await tester.pumpAndSettle();
      expect(find.text('全部媒体库'), findsOneWidget);
      await tester.tap(find.text('来源').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('媒体服务'));
      await tester.pumpAndSettle();
      expect(find.textContaining('添加 Jellyfin'), findsOneWidget);
      tester.view.physicalSize = const Size(390, 760);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.textContaining('添加 Jellyfin'), findsOneWidget);
      await tester.tap(find.text('设置').last);
      await tester.pumpAndSettle();
      expect(find.text('来源默认配置'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.close();
    },
  );

  for (final systemBack in [false, true]) {
    testWidgets('returning stops playback (system back: $systemBack)', (
      tester,
    ) async {
      final service = LibraryService(sqlite3.openInMemory());
      const ref = ResourceRef('s', '/film.mp4');
      service.register(const SourceEntry(ref, 'Film', isFolder: false));
      final resource = service.resourceFor(ref)!['id'] as String;
      service.saveProgress(
        resource,
        service.beginSession(resource),
        const Duration(seconds: 20),
        const Duration(minutes: 1),
      );
      final sources = ShellSources();
      final backend = FakeBackend();
      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(library: service, sources: sources, backend: backend),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Film').first);
      await tester.pumpAndSettle();
      expect(
        backend.opened.single,
        Uri.parse('https://example.test/video.mp4'),
      );
      expect(backend.seeks, [const Duration(seconds: 20)]);
      expect(find.byTooltip('打开文件'), findsNothing);
      expect(find.byTooltip('媒体库'), findsNothing);
      expect(find.byTooltip('媒体源'), findsNothing);
      backend.value = const PlayerSnapshot(
        status: PlaybackStatus.playing,
        position: Duration(seconds: 35),
        duration: Duration(minutes: 1),
        canSeek: true,
      );
      await tester.pump();
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byTooltip('返回'));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('媒体库').last);
      await tester.pumpAndSettle();
      expect(backend.opened, hasLength(1));
      expect(backend.released, isFalse);
      expect(backend.stops, 1);
      expect(sources.releases, 1);
      expect(service.checkpoint(resource)!['position'], 35000);
      expect(backend.value.status, PlaybackStatus.idle);
      expect(find.byTooltip('暂停'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('首页').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Film').first);
      await tester.pumpAndSettle();
      expect(backend.opened, hasLength(2));
      expect(backend.seeks.last, const Duration(seconds: 35));
      await tester.pumpWidget(const SizedBox());
      service.close();
    });
  }
}
