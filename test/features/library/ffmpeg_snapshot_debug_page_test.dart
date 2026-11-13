import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/theme/app_theme.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/library/ffmpeg_snapshot_debug_page.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:openplayx/services/media_processing/media_processing_service.dart';
import 'package:openplayx_ffmpeg/openplayx_ffmpeg.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart';

Widget _host(Widget child) => ShadApp.custom(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: ThemeMode.light,
  appBuilder: (context) => MaterialApp(
    theme: Theme.of(context),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      GlobalShadLocalizations.delegate,
      ...AppLocalizations.localizationsDelegates,
    ],
    builder: (context, child) => ShadAppBuilder(child: child!),
    home: child,
  ),
);

void main() {
  final ext = Platform.isMacOS ? 'dylib' : 'so';
  final lib = File('../ffmpeg-package/build/host/libopenplayx_ffmpeg.$ext')
      .absolute
      .path;
  final skip = File(lib).existsSync() ? null : 'build the host FFmpeg bridge';
  final video = File('test/fixtures/test_video.mp4').absolute.path;

  testWidgets('shows a random snapshot, retakes, and cleans up on leave', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('opx_dbg');
    final db = sqlite3.openInMemory();
    final service = MediaProcessingService(
      db: db,
      sources: SourceManager(),
      root: Future.value(root),
      processor: MediaProcessor(
        libraryPath: lib,
        pollInterval: const Duration(milliseconds: 10),
      ),
    );
    addTearDown(() {
      service.dispose();
      db.close();
      root.deleteSync(recursive: true);
    });
    Future<void> settle() async {
      for (var i = 0; i < 200; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        // Poll timers live in the fake clock; isolate replies in real time.
        await tester.pump(const Duration(milliseconds: 20));
        if (find
            .byKey(const ValueKey('ffmpeg-snapshot-time'))
            .evaluate()
            .isNotEmpty) {
          return;
        }
      }
    }

    await tester.pumpWidget(
      _host(
        FfmpegSnapshotDebugPage(
          service: service,
          resource: ResourceRef('@local', video),
          title: 'Clip',
        ),
      ),
    );
    expect(find.text('Loading…'), findsOneWidget);
    await settle();
    expect(find.textContaining('Frame at '), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    final debugDir = Directory('${root.path}/debug');
    expect(debugDir.listSync(), hasLength(1));

    await tester.tap(find.byKey(const ValueKey('ffmpeg-snapshot-again')));
    await tester.pump();
    await settle();
    expect(find.textContaining('Frame at '), findsOneWidget);
    for (var i = 0; i < 20 && debugDir.listSync().length > 1; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(debugDir.listSync(), hasLength(1)); // previous image deleted

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 20 && debugDir.listSync().isNotEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(debugDir.listSync(), isEmpty);
  }, skip: skip != null);

  testWidgets('reports unavailable module without crashing', (tester) async {
    await tester.pumpWidget(
      _host(
        const FfmpegSnapshotDebugPage(
          service: null,
          resource: ResourceRef('@local', '/x.mp4'),
          title: 'X',
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text('FFmpeg processing is not available in this build.'),
      findsOneWidget,
    );
  });
}
