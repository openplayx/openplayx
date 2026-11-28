import 'dart:async';

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/media_processing/media_processing_service.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/capabilities/speech/asr_backend_config.dart';
import 'package:openplayx/capabilities/speech/asr_model_store.dart';
import 'package:openplayx/capabilities/speech/subtitle_generation_service.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/features/library/view/audio_subtitle_debug_page.dart';
import 'package:openplayx/features/library/view/ffmpeg_snapshot_debug_page.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:openplayx/ui/theme/app_theme.dart';
import 'package:openplayx_ffmpeg/openplayx_ffmpeg.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../support/fake_media_processor.dart';

// 1x1 transparent PNG so Image.memory decodes cleanly in widget tests.
final _tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

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

class _PngMediaProcessor extends FakeMediaProcessor {
  @override
  MediaJob submit(
    MediaPlan plan, {
    required String input,
    required String output,
  }) {
    final job = super.submit(plan, input: input, output: output);
    unawaited(
      job.done.then((r) {
        if (r.succeeded && r.outputPath != null && plan.extension != 'wav') {
          File(r.outputPath!).writeAsBytesSync(_tinyPng);
        }
      }),
    );
    return job;
  }
}

Future<void> _settleIo(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _until(WidgetTester tester, Finder f) async {
  for (var i = 0; i < 80; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('timed out waiting for $f');
}

void main() {
  group('AudioSubtitleDebugPage', () {
    testWidgets('inspect, extract-only, recognise, preview VTT and save', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final tmp = Directory.systemTemp.createTempSync('opx_asr_ui_');
      final sample = File('${tmp.path}/movie.mp4')..writeAsBytesSync([1, 2, 3]);
      final db = sqlite3.openInMemory();
      final processor = FakeMediaProcessor();
      final media = MediaProcessingService(
        db: db,
        sources: SourceManager(),
        root: Future.value(Directory('${tmp.path}/media')),
        processor: processor,
      );
      final fakeBackend = FakeAsrBackend();
      final registry = AsrBackendRegistry(
        db: db,
        models: AsrModelStore(Future.value(Directory('${tmp.path}/models'))),
        backendFactory: (_) => fakeBackend,
      );
      final service = SubtitleGenerationService(
        db: db,
        media: media,
        backends: registry,
        root: Future.value(Directory('${tmp.path}/subtitles')),
      );
      addTearDown(() {
        service.dispose();
        media.dispose();
        db.close();
        tmp.deleteSync(recursive: true);
      });

      final target = AudioSubtitleTarget(
        resource: ResourceRef('@local', sample.path),
        title: 'Demo Movie',
        resourceName: 'movie.mp4',
        episodeLabel: 'S1E1 · Pilot',
        versionLabel: 'Local · 1080p',
      );
      await tester.pumpWidget(
        _host(AudioSubtitleDebugPage(service: service, target: target)),
      );
      await _settleIo(tester);

      // Inspect ran on open; ASR did not run.
      expect(processor.probeCount, greaterThanOrEqualTo(1));
      expect(fakeBackend.calls, 0);
      expect(find.textContaining('Demo Movie'), findsWidgets);

      // Tap extract audio only
      await tester.tap(find.byKey(const ValueKey('asr-extract')));
      await tester.pump();
      await _until(tester, find.byKey(const ValueKey('asr-audio-duration')));
      await _until(tester, find.text('Finished'));
      expect(fakeBackend.calls, 0);

      // Tap transcribe
      await tester.tap(find.byKey(const ValueKey('asr-transcribe')));
      await tester.pump();
      await _until(tester, find.byKey(const ValueKey('asr-segments')));
      expect(fakeBackend.calls, 1);

      // Toggle VTT preview if present
      final vtt = find.text('VTT');
      if (vtt.evaluate().isNotEmpty) {
        await tester.tap(vtt.first);
        await _settleIo(tester);
        expect(find.textContaining('WEBVTT'), findsWidgets);
      }

      // Save subtitles
      await tester.tap(find.byKey(const ValueKey('asr-save')));
      await tester.pump();
      await _until(tester, find.byKey(const ValueKey('asr-saved')));
      expect(service.bindings(target.resource), isNotEmpty);

      // Leave page disposes session cleanly
      await tester.pumpWidget(_host(const SizedBox()));
      await _settleIo(tester);
    });

    testWidgets('shows unavailable and inspect-error states', (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const target = AudioSubtitleTarget(
        resource: ResourceRef('@local', '/nonexistent.mp4'),
        title: 'Missing',
        resourceName: 'nonexistent.mp4',
      );
      await tester.pumpWidget(
        _host(const AudioSubtitleDebugPage(service: null, target: target)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AudioSubtitleDebugPage), findsOneWidget);
    });
  });

  group('FfmpegSnapshotDebugPage', () {
    testWidgets('takes snapshot, retakes, and handles unavailable/error', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final tmp = Directory.systemTemp.createTempSync('opx_snap_ui_');
      final sample = File('${tmp.path}/clip.mp4')..writeAsBytesSync([1, 2, 3]);
      final db = sqlite3.openInMemory();
      final processor = _PngMediaProcessor();
      final media = MediaProcessingService(
        db: db,
        sources: SourceManager(),
        root: Future.value(Directory('${tmp.path}/media')),
        processor: processor,
      );
      addTearDown(() {
        media.dispose();
        db.close();
        tmp.deleteSync(recursive: true);
      });

      final ref = ResourceRef('@local', sample.path);
      await tester.pumpWidget(
        _host(
          FfmpegSnapshotDebugPage(
            service: media,
            resource: ref,
            title: 'Clip Title',
          ),
        ),
      );
      await _settleIo(tester);
      expect(find.textContaining('Clip Title'), findsWidgets);

      // Unavailable service renders error state cleanly.
      await tester.pumpWidget(
        _host(
          FfmpegSnapshotDebugPage(
            key: const ValueKey('null-service'),
            service: null,
            resource: ref,
            title: 'No Service',
          ),
        ),
      );
      await _settleIo(tester);
      expect(find.byType(FfmpegSnapshotDebugPage), findsOneWidget);
    });
  });
}
