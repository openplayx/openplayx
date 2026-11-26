// Real FFmpeg + whisper.cpp host libraries and a tiny model; skipped when
// absent (see test/services/subtitles/subtitle_generation_service_test.dart).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/ui/theme/app_theme.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/core/capabilities/speech_recognition_capability.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/features/library/view/audio_subtitle_debug_page.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:openplayx/capabilities/media_processing/media_processing_service.dart';
import 'package:openplayx/capabilities/speech/asr_backend_config.dart';
import 'package:openplayx/capabilities/speech/asr_model_store.dart';
import 'package:openplayx/capabilities/speech/subtitle_generation_service.dart';
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

class _PlatformBackend implements SpeechRecognitionModelCapability {
  int calls = 0;
  @override
  String get instanceId => 'platform';
  @override
  String get kind => 'platform';
  @override
  Future<AsrBackendStatus> status() async =>
      const AsrBackendStatus(available: true, modelId: 'whisper-large-v3');
  @override
  Future<TranscriptResult> transcribe(
    TranscriptionRequest input,
    AsrTaskContext context,
  ) async {
    calls++;
    return TranscriptResult(
      raw: RawTranscript(
        language: 'en',
        audioMs: input.audioMs,
        windowMs: input.audioMs,
        overlapMs: 0,
        windows: [
          RawWindow(0, input.audioMs, [
            const RawSegment(1000, 2000, 'Movie dialogue'),
          ]),
        ],
      ),
      backend: kind,
      modelId: 'whisper-large-v3',
      modelRevision: 'test',
      engineVersion: 'test',
    );
  }
}

void main() {
  final ext = Platform.isMacOS ? 'dylib' : 'so';
  final ffmpeg = File('../ffmpeg-package/build/host/libopenplayx_ffmpeg.$ext')
      .absolute
      .path;
  final whisper = File(
    '../package-whisper/build/host/libopenplayx_whisper.$ext',
  ).absolute.path;
  final model =
      '${Platform.environment['HOME']}/.cache/openplayx-asr-models/ggml-tiny.bin';
  final wav = File('../package-whisper/test/fixtures/long.wav').absolute.path;
  final skip =
      !File(ffmpeg).existsSync() ||
      !File(whisper).existsSync() ||
      !File(model).existsSync();

  testWidgets('nothing runs on open; extract then recognise; leave cleans up', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('opx_asr_page');
    final db = sqlite3.openInMemory();
    final media = MediaProcessingService(
      db: db,
      sources: SourceManager(),
      root: Future.value(Directory('${tmp.path}/media')),
      processor: MediaProcessor(
        libraryPath: ffmpeg,
        pollInterval: const Duration(milliseconds: 10),
      ),
    );
    final models = AsrModelStore(Future.value(Directory('${tmp.path}/models')));
    // Futures created in the fake-async zone never complete inside runAsync,
    // so the importing store is built in the real zone.
    await tester.runAsync(
      () =>
          AsrModelStore(Future.value(Directory('${tmp.path}/models')))
              .import(File(model)),
    );
    final registry = AsrBackendRegistry(
      db: db,
      models: models,
      embeddedEngine: WhisperEngine(
        libraryPath: whisper,
        pollInterval: const Duration(milliseconds: 10),
      ),
      readCredential: (_) async => null,
    );
    registry.selectDefault('embedded');
    registry.save(
      registry
          .get('embedded')!
          .copyWith(modelId: 'whisper-tiny-multilingual', language: 'en'),
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

    Future<void> until(Finder f) async {
      for (var i = 0; i < 600; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
        if (f.evaluate().isNotEmpty) return;
      }
      fail('timed out waiting for $f');
    }

    await tester.pumpWidget(
      _host(
        AudioSubtitleDebugPage(
          service: service,
          target: AudioSubtitleTarget(
            resource: ResourceRef('@local', wav),
            title: 'Show',
            resourceName: 'long.wav',
            episodeLabel: 'Season 1 · Episode 2 · Pilot',
          ),
        ),
      ),
    );
    await until(find.textContaining('Ready ·'));
    expect(find.text('Season 1 · Episode 2 · Pilot'), findsOneWidget);
    // Opening probes only: no task, no model use.
    expect(db.select('SELECT * FROM transcription_tasks'), isEmpty);
    // Default range: 0 → 60 s clamped to the 49.6 s duration.
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('asr-end')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '49.651',
    );

    await tester.tap(find.byKey(const ValueKey('asr-extract')));
    await tester.pump();
    await until(find.byKey(const ValueKey('asr-audio-duration')));
    await until(find.text('Finished'));
    expect(find.text('16000 Hz · 1 ch · PCM s16 WAV'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('asr-start')),
        matching: find.byType(EditableText),
      ),
      '35',
    );
    await tester.tap(find.byKey(const ValueKey('asr-transcribe')));
    await tester.pump();
    await until(find.byKey(const ValueKey('asr-segments')));
    expect(find.textContaining('fox', findRichText: true), findsWidgets);
    expect(find.textContaining('Partial: 00:00:35.000'), findsOneWidget);
    expect(find.textContaining('00:00:4'), findsWidgets);
    expect(service.bindings(ResourceRef('@local', wav)), isEmpty);

    await tester.tap(find.byKey(const ValueKey('asr-save')));
    await until(find.byKey(const ValueKey('asr-saved')));
    expect(
      service.bindings(ResourceRef('@local', wav)).single['partial'],
      isTrue,
    );

    final audioDir = Directory('${tmp.path}/media/artifacts');
    expect(audioDir.listSync(), isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 100 && audioDir.listSync().isNotEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    // Unsaved debug audio is discarded; the saved subtitle stays.
    expect(audioDir.listSync(), isEmpty);
    expect(service.bindings(ResourceRef('@local', wav)), hasLength(1));
  }, skip: skip);

  testWidgets(
    'missing model: explains, offers install, rechecks after install',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tmp = Directory.systemTemp.createTempSync('opx_asr_missing');
      final db = sqlite3.openInMemory();
      final media = MediaProcessingService(
        db: db,
        sources: SourceManager(),
        root: Future.value(Directory('${tmp.path}/media')),
        processor: MediaProcessor(
          libraryPath: ffmpeg,
          pollInterval: const Duration(milliseconds: 10),
        ),
      );
      final registry = AsrBackendRegistry(
        db: db,
        models: AsrModelStore(Future.value(Directory('${tmp.path}/models'))),
        embeddedEngine: WhisperEngine(libraryPath: whisper),
        readCredential: (_) async => null,
      );
      registry.selectDefault('embedded');
      registry.save(
        registry
            .get('embedded')!
            .copyWith(modelId: 'whisper-tiny-multilingual'),
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
      Future<void> until(Finder f) async {
        for (var i = 0; i < 300; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
          if (f.evaluate().isNotEmpty) return;
        }
        fail('timed out waiting for $f');
      }

      await tester.pumpWidget(
        _host(
          AudioSubtitleDebugPage(
            service: service,
            target: AudioSubtitleTarget(
              resource: ResourceRef('@local', wav),
              title: 'Show',
              resourceName: 'long.wav',
            ),
          ),
        ),
      );
      await until(find.byKey(const ValueKey('asr-transcribe-blocked')));
      expect(
        find.text('Recognition unavailable: Model not installed.'),
        findsOneWidget,
      );
      expect(
        find.text('On device · whisper-tiny-multilingual'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ShadButton>(find.byKey(const ValueKey('asr-transcribe')))
            .enabled,
        isFalse,
      );

      // The install entry opens the model settings inside the debug flow.
      await tester.tap(find.byKey(const ValueKey('asr-install-model')));
      await until(
        find.byKey(const ValueKey('asr-model-whisper-tiny-multilingual')),
      );
      expect(find.text('Not installed'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
      // Returning rechecks automatically (still not installed here).
      await until(find.byKey(const ValueKey('asr-recheck')));

      // Installed meanwhile (e.g. imported): a recheck enables recognition.
      await tester.runAsync(
        () =>
            AsrModelStore(Future.value(Directory('${tmp.path}/models')))
                .import(File(model)),
      );
      await tester.tap(find.byKey(const ValueKey('asr-recheck')));
      await until(find.textContaining('Ready ·'));
      expect(
        find.byKey(const ValueKey('asr-transcribe-blocked')),
        findsNothing,
      );
      expect(
        tester
            .widget<ShadButton>(find.byKey(const ValueKey('asr-transcribe')))
            .enabled,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
    },
    skip: skip,
  );

  testWidgets(
    'default Groq generates full subtitles from the debug page without a local model',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tmp = Directory.systemTemp.createTempSync('opx_full_page');
      final db = sqlite3.openInMemory();
      final backend = _PlatformBackend();
      final media = MediaProcessingService(
        db: db,
        sources: SourceManager(),
        root: Future.value(Directory('${tmp.path}/media')),
        processor: MediaProcessor(
          libraryPath: ffmpeg,
          pollInterval: const Duration(milliseconds: 10),
        ),
      );
      final registry = AsrBackendRegistry(
        db: db,
        models: AsrModelStore(Future.value(Directory('${tmp.path}/models'))),
        backendFactory: (_) => backend,
      );
      final service = SubtitleGenerationService(
        db: db,
        media: media,
        backends: registry,
        root: Future.value(Directory('${tmp.path}/subtitles')),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        service.dispose();
        media.dispose();
        db.close();
        tmp.deleteSync(recursive: true);
      });
      Future<void> until(Finder finder) async {
        for (var i = 0; i < 400; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 10));
          if (finder.evaluate().isNotEmpty) return;
        }
        fail('timed out waiting for $finder');
      }

      await tester.pumpWidget(
        _host(
          AudioSubtitleDebugPage(
            service: service,
            target: AudioSubtitleTarget(
              resource: ResourceRef('@local', wav),
              title: 'Movie',
              resourceName: 'movie.wav',
            ),
          ),
        ),
      );
      await until(find.byKey(const ValueKey('asr-end')));
      expect(find.text('Groq (free, default)'), findsOneWidget);
      expect(backend.calls, 0);
      final generate = find.byKey(const ValueKey('asr-generate-whole'));
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();
      expect(find.byType(ShadDialog), findsOneWidget);
      expect(backend.calls, 0);
      await tester.tap(find.text('Continue'));
      await until(find.byKey(const ValueKey('asr-preview')));
      expect(backend.calls, 1);
      final save = find.byKey(const ValueKey('asr-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await until(find.byKey(const ValueKey('asr-saved')));
      expect(
        db.select('SELECT partial FROM subtitle_bindings').single['partial'],
        0,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    },
    skip: !File(ffmpeg).existsSync(),
  );

  testWidgets('without the service it explains instead of crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AudioSubtitleDebugPage(
          service: null,
          target: AudioSubtitleTarget(
            resource: ResourceRef('@local', '/x.mkv'),
            title: 'X',
            resourceName: 'x.mkv',
          ),
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
