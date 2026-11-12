import '../app_test_host.dart';

import 'package:openplayx/features/library/home_page.dart';
import 'package:openplayx/ui/adaptive/app_navigation.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app_shell.dart';
import 'package:openplayx/features/player/player_page.dart';
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
  for (final cancel in [true, false]) {
    testWidgets(
      'file selection reveals the player only after choosing a file (cancel: $cancel)',
      (tester) async {
        final library = LibraryService(sqlite3.openInMemory());
        final backend = FakeBackend();
        final selection = Completer<LocalMedia?>();
        var pickerCalls = 0;
        await tester.pumpWidget(
          TestApp(
            home: AppShell(
              library: library,
              sources: ShellSources(),
              backend: backend,
              pickMedia: () {
                pickerCalls++;
                return selection.future;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final player = tester.state<PlayerPageState>(
          find.byType(PlayerPage, skipOffstage: false),
        );
        final opening = player.openFile();
        await tester.pump();
        expect(find.byType(HomePage), findsOneWidget);
        expect(find.byTooltip('返回'), findsNothing);
        await player.openFile();
        await tester.pump();
        expect(pickerCalls, 1);
        selection.complete(
          cancel
              ? null
              : LocalMedia(
                  Uri.parse('https://example.test/local.mp4'),
                  'Local video',
                ),
        );
        await opening;
        await tester.pumpAndSettle();
        if (cancel) {
          expect(find.byType(HomePage), findsOneWidget);
          expect(find.byTooltip('返回'), findsNothing);
          expect(backend.opened, isEmpty);
          expect(backend.value.status, PlaybackStatus.idle);
          // The library tab is gone; browsing lives on the home shelves.
          expect(find.byKey(const ValueKey('nav-library')), findsNothing);
        } else {
          expect(find.byType(HomePage), findsNothing);
          expect(find.byTooltip('返回'), findsOneWidget);
          expect(backend.opened, [Uri.parse('https://example.test/local.mp4')]);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        library.close();
      },
    );
  }

  testWidgets(
    'responsive navigation retains library selection and unified sources',
    (tester) async {
      final service = LibraryService(sqlite3.openInMemory());
      service.create('Movies');
      final backend = FakeBackend();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        TestApp(
          home: AppShell(
            library: service,
            sources: ShellSources(),
            backend: backend,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-library')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('nav-sources')));
      await tester.pumpAndSettle();
      expect(find.text('NAS'), findsOneWidget);
      expect(find.byType(SegmentedButton<bool>), findsNothing);
      tester.view.physicalSize = const Size(390, 760);
      await tester.pumpAndSettle();
      expect(find.byType(AppBottomBar), findsOneWidget);
      expect(find.text('NAS'), findsOneWidget);
      expect(find.byType(SegmentedButton<bool>), findsNothing);
      await tester.tap(find.byKey(const ValueKey('nav-settings')));
      await tester.pumpAndSettle();
      // Phone settings is a category menu; categories open sub-pages.
      expect(find.text('扫描的文件后缀'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('settings-来源')));
      await tester.pumpAndSettle();
      expect(find.text('扫描的文件后缀'), findsOneWidget);
      // Secondary pages hide the bottom bar; returning brings it back.
      expect(find.byType(AppBottomBar), findsNothing);
      Navigator.of(tester.element(find.text('扫描的文件后缀'))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(AppBottomBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
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
        TestApp(
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
      await tester.tap(find.byKey(const ValueKey('nav-sources')));
      await tester.pumpAndSettle();
      expect(backend.opened, hasLength(1));
      expect(backend.released, isFalse);
      expect(backend.stops, 1);
      expect(sources.releases, 1);
      expect(service.checkpoint(resource)!['position'], 35000);
      expect(backend.value.status, PlaybackStatus.idle);
      expect(find.byTooltip('暂停'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('nav-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Film').first);
      await tester.pumpAndSettle();
      expect(backend.opened, hasLength(2));
      expect(backend.seeks.last, const Duration(seconds: 35));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      service.close();
    });
  }
}
