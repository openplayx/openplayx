import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app_shell.dart';
import 'package:openplayx/app/app_navigation.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/files/local_media_picker.dart';
import 'package:openplayx/features/library/view/media_detail_page.dart';
import 'package:openplayx/features/player/view/player_page.dart';
import 'package:openplayx/ui/adaptive/app_experience.dart';
import 'package:openplayx/ui/tv/tv_action.dart';
import 'package:sqlite3/sqlite3.dart';

import '../app_test_host.dart';
import '../support/fake_sources.dart';
import '../support/library_test_helpers.dart';
import 'player/player_page_test.dart' show FakeBackend;

class TvSources extends Sources {
  @override
  Future<PlayableStream> resolve(ResourceRef ref) async =>
      PlayableStream(Uri.parse('https://example.test/movie.mp4'));
}

void main() {
  void screenSize(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Widget host(Widget child) =>
      AppExperience(television: true, child: TestApp(home: child));

  testWidgets('remote select activates once; route pop restores tile focus', (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    var opens = 0;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => Scaffold(
            body: TvAction(
              focusNode: node,
              autofocus: true,
              onPressed: () {
                opens++;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: TvAction(
                        autofocus: true,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back'),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Movie'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(opens, 1);
    await key(tester, LogicalKeyboardKey.enter);
    expect(node.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'TV seek previews, cancels, commits; panel traps and restores focus',
    (tester) async {
      screenSize(tester, const Size(1280, 720));
      final backend = FakeBackend();
      await tester.pumpWidget(
        host(
          PlayerPage(
            backend: backend,
            pickMedia: () async => LocalMedia(Uri.file('/demo.mp4'), 'Demo'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.state<PlayerPageState>(find.byType(PlayerPage)).openFile();
      await tester.pumpAndSettle();
      void focus(String id) => tester
          .widget<TvAction>(find.byKey(ValueKey('tv-player-$id')))
          .focusNode!
          .requestFocus();
      focus('play');
      await tester.pump();
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(backend.seeks, isEmpty, reason: 'arrows navigate controls');
      expect(backend.volumes, isEmpty, reason: 'arrows do not change volume');
      focus('seek');
      await tester.pump();
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(backend.seeks, isEmpty, reason: 'preview is not a backend seek');
      await key(tester, LogicalKeyboardKey.escape);
      expect(backend.seeks, isEmpty);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await key(tester, LogicalKeyboardKey.select);
      expect(backend.seeks, [const Duration(seconds: 10)]);
      focus('subtitles');
      await tester.pump();
      await key(tester, LogicalKeyboardKey.select);
      expect(find.byKey(const ValueKey('tv-panel-subtitles')), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await key(tester, LogicalKeyboardKey.arrowLeft);
      }
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(focused.findAncestorWidgetOfExactType<FocusScope>(), isNotNull);
      expect(
        find.ancestor(
          of: find.byWidget(focused.widget),
          matching: find.byKey(const ValueKey('tv-panel-subtitles')),
        ),
        findsOneWidget,
      );
      await key(tester, LogicalKeyboardKey.escape);
      expect(
        tester
            .widget<TvAction>(find.byKey(const ValueKey('tv-player-subtitles')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await key(tester, LogicalKeyboardKey.escape);
      expect(find.byKey(const ValueKey('tv-player-play')), findsNothing);
      await key(tester, LogicalKeyboardKey.enter);
      expect(find.byKey(const ValueKey('tv-player-play')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'real library: home to detail to playback and back using remote',
    (tester) async {
      screenSize(tester, const Size(1280, 720));
      final library = LibraryService(sqlite3.openInMemory());
      addTearDown(library.close);
      final id = library.register(
        const SourceEntry(
          ResourceRef('test', '/movie.mkv'),
          'TV movie',
          isFolder: false,
        ),
      );
      addToLibrary(library, id);
      final backend = FakeBackend();
      final capture = GlobalKey();
      const previewDirectory = String.fromEnvironment('OPX_TV_PREVIEW_DIR');
      if (previewDirectory.isNotEmpty) {
        await tester.runAsync(() async {
          final manifest = jsonDecode(
            await rootBundle.loadString('FontManifest.json'),
          ) as List;
          for (final font in manifest) {
            final loader = FontLoader(font['family'] as String);
            for (final asset in font['fonts'] as List) {
              loader.addFont(
                rootBundle.load(Uri.decodeFull(asset['asset'] as String)),
              );
            }
            await loader.load();
          }
          const fontPath = String.fromEnvironment('OPX_TV_PREVIEW_FONT');
          if (fontPath.isNotEmpty) {
            final bytes = ByteData.sublistView(
              await File(fontPath).readAsBytes(),
            );
            for (final family in ['PingFang SC', 'Ahem']) {
              await (FontLoader(family)..addFont(Future.value(bytes))).load();
            }
          }
        });
      }
      Future<void> screenshot(String name) async {
        const directory = String.fromEnvironment('OPX_TV_PREVIEW_DIR');
        if (directory.isEmpty) return;
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$directory/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: host(
            AppShell(library: library, sources: TvSources(), backend: backend),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TvSidebar), findsOneWidget);
      expect(find.byType(AppBottomBar), findsNothing);
      await screenshot('tv-home');
      await key(tester, LogicalKeyboardKey.select);
      expect(find.byType(MediaDetailPage), findsOneWidget);
      expect(find.byKey(const ValueKey('tv-detail-play')), findsOneWidget);
      await screenshot('tv-detail');
      await key(tester, LogicalKeyboardKey.select);
      expect(backend.opened, [Uri.parse('https://example.test/movie.mp4')]);
      expect(find.byKey(const ValueKey('tv-player-play')), findsOneWidget);
      await screenshot('tv-player');
      await key(tester, LogicalKeyboardKey.escape);
      await key(tester, LogicalKeyboardKey.escape);
      expect(find.byKey(const ValueKey('tv-detail-play')), findsOneWidget);
      expect(backend.stops, 1);
      await key(tester, LogicalKeyboardKey.select);
      expect(
        backend.opened.length,
        2,
        reason: 'return restores detail play focus',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tv-player-play')), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(backend.stops, 2);
      await key(tester, LogicalKeyboardKey.escape);
      expect(find.byType(MediaDetailPage), findsNothing);
      await key(tester, LogicalKeyboardKey.select);
      expect(
        find.byKey(const ValueKey('tv-detail-play')),
        findsOneWidget,
        reason: 'detail pop restores the original home tile',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
