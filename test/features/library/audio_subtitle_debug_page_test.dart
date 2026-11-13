// Real FFmpeg + whisper.cpp host libraries and a tiny model; skipped when
// absent (see test/services/subtitles/subtitle_generation_service_test.dart).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/theme/app_theme.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/library/audio_subtitle_debug_page.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:openplayx/services/media_processing/media_processing_service.dart';
import 'package:openplayx/services/subtitles/asr_backend_config.dart';
import 'package:openplayx/services/subtitles/asr_model_store.dart';
import 'package:openplayx/services/subtitles/subtitle_generation_service.dart';
import 'package:openplayx_ffmpeg/openplayx_ffmpeg.dart';
import 'package:openplayx_whisper/openplayx_whisper.dart';
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
  final ffmpeg = File('../ffmpeg-package/build/host/libopenplayx_ffmpeg.$ext').absolute.path;
  final whisper = File('../whisper-package/build/host/libopenplayx_whisper.$ext').absolute.path;
  final model = '${Platform.environment['HOME']}/.cache/openplayx-asr-models/ggml-tiny.bin';
  final wav = File('../whisper-package/test/fixtures/long.wav').absolute.path;
  final skip = !File(ffmpeg).existsSync() || !File(whisper).existsSync() || !File(model).existsSync();

  testWidgets('nothing runs on open; extract then recognise; leave cleans up', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('opx_asr_page');
    final db = sqlite3.openInMemory();
    final media = MediaProcessingService(
      db: db,
      sources: SourceManager(),
      root: Future.value(Directory('${tmp.path}/media')),
      processor: MediaProcessor(libraryPath: ffmpeg, pollInterval: const Duration(milliseconds: 10)),
    );
    final models = AsrModelStore(Future.value(Directory('${tmp.path}/models')));
    // Futures created in the fake-async zone never complete inside runAsync,
    // so the importing store is built in the real zone.
    await tester.runAsync(
      () => AsrModelStore(Future.value(Directory('${tmp.path}/models'))).import(File(model)),
    );
    final registry = AsrBackendRegistry(
      db: db,
      models: models,
      embeddedEngine: WhisperEngine(libraryPath: whisper, pollInterval: const Duration(milliseconds: 10)),
      readCredential: (_) async => null,
    );
    registry.save(registry.get('embedded')!.copyWith(modelId: 'whisper-tiny-multilingual', language: 'en'));
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

    Future<void> until(Finder f) async {
      for (var i = 0; i < 600; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 20));
        if (f.evaluate().isNotEmpty) return;
      }
      fail('timed out waiting for $f');
    }

    await tester.pumpWidget(_host(AudioSubtitleDebugPage(
      service: service,
      target: AudioSubtitleTarget(
        resource: ResourceRef('@local', wav),
        title: 'Show',
        resourceName: 'long.wav',
        episodeLabel: 'Season 1 · Episode 2 · Pilot',
      ),
    )));
    await until(find.textContaining('Ready ·'));
    expect(find.text('Season 1 · Episode 2 · Pilot'), findsOneWidget);
    // Opening probes only: no task, no model use.
    expect(db.select('SELECT * FROM transcription_tasks'), isEmpty);
    // Default range: 0 → 60 s clamped to the 49.6 s duration.
    expect(tester.widget<EditableText>(find.descendant(of: find.byKey(const ValueKey('asr-end')), matching: find.byType(EditableText))).controller.text, '49.651');

    await tester.tap(find.byKey(const ValueKey('asr-extract')));
    await tester.pump();
    await until(find.byKey(const ValueKey('asr-audio-duration')));
    await until(find.text('Finished'));
    expect(find.text('16000 Hz · 1 ch · PCM s16 WAV'), findsOneWidget);

    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('asr-start')), matching: find.byType(EditableText)), '35');
    await tester.tap(find.byKey(const ValueKey('asr-transcribe')));
    await tester.pump();
    await until(find.byKey(const ValueKey('asr-segments')));
    expect(find.textContaining('fox', findRichText: true), findsWidgets);
    expect(find.textContaining('Partial: 00:00:35.000'), findsOneWidget);
    expect(find.textContaining('00:00:4'), findsWidgets);
    expect(service.bindings(ResourceRef('@local', wav)), isEmpty);

    await tester.tap(find.byKey(const ValueKey('asr-save')));
    await until(find.byKey(const ValueKey('asr-saved')));
    expect(service.bindings(ResourceRef('@local', wav)).single['partial'], isTrue);

    final audioDir = Directory('${tmp.path}/media/artifacts');
    expect(audioDir.listSync(), isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 100 && audioDir.listSync().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    // Unsaved debug audio is discarded; the saved subtitle stays.
    expect(audioDir.listSync(), isEmpty);
    expect(service.bindings(ResourceRef('@local', wav)), hasLength(1));
  }, skip: skip);

  testWidgets('without the service it explains instead of crashing', (tester) async {
    await tester.pumpWidget(_host(const AudioSubtitleDebugPage(
      service: null,
      target: AudioSubtitleTarget(resource: ResourceRef('@local', '/x.mkv'), title: 'X', resourceName: 'x.mkv'),
    )));
    await tester.pump();
    expect(find.text('FFmpeg processing is not available in this build.'), findsOneWidget);
  });
}
