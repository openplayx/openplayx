import '../app_test_host.dart';

import 'package:openplayx/features/library/view/home_page.dart';
import 'package:openplayx/app/app_navigation.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app_shell.dart';
import 'package:openplayx/features/player/view/player_page.dart';
import 'package:openplayx/features/assistant/view/ai_chat_view.dart';
import 'package:openplayx/ui/icons/app_icons.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:openplayx_playback/playback.dart';

import '../support/fake_sources.dart';
import 'player/player_page_test.dart' show FakeBackend;
import '../support/library_test_helpers.dart';

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
  for (final layout in [
    (TargetPlatform.android, const Size(390, 844)),
    (TargetPlatform.iOS, const Size(844, 390)),
    (TargetPlatform.macOS, const Size(800, 600)),
    (TargetPlatform.macOS, const Size(1200, 800)),
  ]) {
    testWidgets('${layout.$1.name} ${layout.$2}: AI follows player controls', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = layout.$1;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = layout.$2;
      addTearDown(tester.view.reset);
      final library = LibraryService(sqlite3.openInMemory());
      await tester.pumpWidget(
        TestApp(
          home: AppShell(
            library: library,
            sources: ShellSources(),
            backend: FakeBackend(),
            pickMedia: () async => LocalMedia(
              Uri.parse('https://example.test/video.mp4'),
              'Video',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final player = tester.state<PlayerPageState>(
        find.byType(PlayerPage, skipOffstage: false),
      );
      await player.openFile();
      await tester.pumpAndSettle();

      final ai = find.byIcon(AppIcons.assistant);
      Finder fadeOf(Finder control) => find
          .ancestor(of: control, matching: find.byType(AnimatedOpacity))
          .first;
      void expectVisibility(bool visible) {
        final aiFade = tester.widget<AnimatedOpacity>(fadeOf(ai));
        final playerFade = tester.widget<AnimatedOpacity>(
          fadeOf(find.byTooltip('返回')),
        );
        expect(aiFade.opacity, visible ? 1 : 0);
        expect(aiFade.opacity, playerFade.opacity);
        expect(aiFade.duration, playerFade.duration);
        expect(aiFade.curve, playerFade.curve);
        expect(ai.hitTestable(), visible ? findsOneWidget : findsNothing);
        expect(
          tester
              .widget<ExcludeSemantics>(
                find
                    .ancestor(
                      of: fadeOf(ai),
                      matching: find.byType(ExcludeSemantics),
                    )
                    .first,
              )
              .excluding,
          !visible,
        );
      }

      Future<void> toggleControls() async {
        if (layout.$1 == TargetPlatform.macOS) {
          // The shell initially mounts the player offstage. Give keyboard
          // input to its focus scope before exercising the shortcut.
          tester
              .widget<Focus>(
                find
                    .ancestor(
                      of: find.byKey(const Key('video-gestures')),
                      matching: find.byWidgetPredicate(
                        (widget) =>
                            widget is Focus &&
                            widget.focusNode?.debugLabel == 'player-keyboard',
                      ),
                    )
                    .first,
              )
              .focusNode!
              .requestFocus();
          await tester.pump();
          // Desktop defaults to click-to-pause; I toggles its controls.
          await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
        } else {
          await tester.tapAt(const Offset(80, 200));
          // A single tap waits for the double-tap recognizer to expire.
          await tester.pump(kDoubleTapTimeout);
        }
        await tester.pumpAndSettle();
      }

      expectVisibility(true);
      await toggleControls();
      expectVisibility(false);
      await toggleControls();
      expectVisibility(true);
      final delay = layout.$1 == TargetPlatform.macOS
          ? const Duration(seconds: 2)
          : const Duration(seconds: 4);
      await tester.pump(delay);
      await tester.pumpAndSettle();
      expectVisibility(false);
      await toggleControls();
      expectVisibility(true);

      await tester.tap(find.byTooltip('AI 助手'));
      await tester.pumpAndSettle();
      expect(find.byType(AiChatView), findsOneWidget);
      await tester.pump(delay);
      await tester.pumpAndSettle();
      expect(player.controlsVisibility.value, isFalse);
      expect(find.byType(AiChatView), findsOneWidget);
      Navigator.of(tester.element(find.byType(AiChatView))).pop();
      await tester.pumpAndSettle();
      expectVisibility(false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      library.close();
    });
  }

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
      // Fixed order: 首页 → 来源 → AI → 设置, with AI one tap away.
      final order = [
        for (final name in ['home', 'sources', 'plugins', 'settings'])
          tester.getCenter(find.byKey(ValueKey('nav-$name'))).dx,
      ];
      expect(order, List.of(order)..sort());
      await tester.tap(find.byKey(const ValueKey('nav-plugins')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AiChatView), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-composer-input')), findsOneWidget);
      expect(find.byKey(const ValueKey('plugin-group-model')), findsNothing);
      expect(find.byIcon(AppIcons.assistant), findsNothing);
      expect(find.byType(AppBottomBar), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-settings')));
      await tester.pumpAndSettle();
      // AI configuration now lives in Settings, with its return path intact.
      await tester.tap(find.byKey(const ValueKey('settings-AI')));
      await tester.pumpAndSettle();
      for (final group in ['model', 'external', 'builtIn']) {
        expect(find.byKey(ValueKey('plugin-group-$group')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('plugin-group-model')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plugin-group-model')), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-AI')), findsOneWidget);

      // Chat's model shortcut opens the same configuration under Settings.
      await tester.tap(find.byKey(const ValueKey('nav-plugins')));
      await tester.pumpAndSettle();
      tester.widget<AiChatView>(find.byType(AiChatView)).onSettings();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('plugin-group-page-model')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plugin-group-model')), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-AI')), findsOneWidget);
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
      addToLibrary(
        service,
        service.register(const SourceEntry(ref, 'Film', isFolder: false)),
      );
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

  testWidgets('phones hide the system bars only while the player is shown', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final modes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          modes.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final service = LibraryService(sqlite3.openInMemory());
    const ref = ResourceRef('s', '/film.mp4');
    addToLibrary(
      service,
      service.register(const SourceEntry(ref, 'Film', isFolder: false)),
    );
    final resource = service.resourceFor(ref)!['id'] as String;
    service.saveProgress(
      resource,
      service.beginSession(resource),
      const Duration(seconds: 20),
      const Duration(minutes: 1),
    );
    await tester.pumpWidget(
      TestApp(
        home: AppShell(
          library: service,
          sources: ShellSources(),
          backend: FakeBackend(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The player is mounted offstage, but browsing keeps the bars visible.
    expect(modes, isEmpty);
    await tester.tap(find.text('Film').first);
    await tester.pumpAndSettle();
    expect(modes, ['SystemUiMode.immersiveSticky']);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(modes, ['SystemUiMode.immersiveSticky', 'SystemUiMode.edgeToEdge']);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(modes, hasLength(2));
    service.close();
    debugDefaultTargetPlatformOverride = null;
  });
}
