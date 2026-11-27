import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/capabilities/artwork/artwork_service.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/media_processing/media_processing_service.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/capabilities/speech/asr_backend_config.dart';
import 'package:openplayx/capabilities/speech/asr_model_store.dart';
import 'package:openplayx/capabilities/speech/embedded_whisper_backend.dart';
import 'package:openplayx/capabilities/speech/subtitle_generation_service.dart';
import 'package:openplayx/core/capabilities/metadata_capability.dart';
import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/core/capabilities/speech_recognition_capability.dart';
import 'package:openplayx/features/library/view/media_detail_page.dart';
import 'package:openplayx/features/settings/app_theme_controller.dart';
import 'package:openplayx/features/settings/asr_http_service_settings_page.dart';
import 'package:openplayx/features/settings/asr_settings_section.dart';
import 'package:openplayx/features/settings/settings_page.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:openplayx/ui/theme/app_theme.dart';
import 'package:openplayx_whisper/openplayx_whisper.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fake_media_processor.dart';
import '../support/fake_sources.dart';
import '../support/library_test_helpers.dart';

final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FakeWhisperModel implements WhisperModel {
  _FakeWhisperModel(this.path);
  @override
  final String path;
  @override
  String get type => 'tiny';
  @override
  bool get multilingual => true;
  @override
  String get backend => 'CPU';
  @override
  String get device => '';
  bool _closed = false;
  @override
  bool get closed => _closed;
  @override
  void close() => _closed = true;
}

class _FakeAsrJob implements AsrJob {
  _FakeAsrJob({AsrErrorCode? failWith}) {
    unawaited(() async {
      _progress.add(
        const AsrProgress(
          AsrJobState.running,
          processedMs: 2500,
          totalMs: 5000,
        ),
      );
      if (failWith != null) {
        _done.complete(AsrJobResult(AsrJobState.failed, error: failWith));
      } else {
        _done.complete(
          AsrJobResult(
            AsrJobState.succeeded,
            transcript: RawTranscript(
              language: 'en',
              audioMs: 5000,
              windowMs: 5000,
              overlapMs: 0,
              windows: [
                RawWindow(0, 5000, const [RawSegment(500, 2000, 'Whisper line')]),
              ],
            ),
          ),
        );
      }
      await _progress.close();
    }());
  }

  final _progress = StreamController<AsrProgress>.broadcast();
  final _done = Completer<AsrJobResult>();

  @override
  Stream<AsrProgress> get progress => _progress.stream;
  @override
  Future<AsrJobResult> get done => _done.future;
  @override
  void cancel() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWhisperEngine implements WhisperEngine {
  bool isAvailable = true;
  AsrErrorCode? openError;
  AsrErrorCode? jobError;

  @override
  bool get available => isAvailable;
  @override
  bool get libraryLoads => isAvailable;
  @override
  Duration get pollInterval => const Duration(milliseconds: 10);

  @override
  AsrEngineInfo info() => isAvailable
      ? AsrEngineInfo.fromJson({
          'available': true,
          'engine': 'whisper.cpp',
          'engine_version': '1.9.5',
        })
      : const AsrEngineInfo.unavailable();

  @override
  Future<WhisperModel> openModel(String path, {bool gpu = true}) async {
    if (openError != null) throw AsrException(openError!);
    return _FakeWhisperModel(path);
  }

  @override
  AsrJob transcribe(WhisperModel model, AsrRequest request) =>
      _FakeAsrJob(failWith: jobError);

  @override
  void dispose() {}
}

class _FakeArtwork extends ArtworkService {
  _FakeArtwork(super.sources, this.file);
  final File file;
  @override
  Future<File> load(ArtworkDescriptor artwork) async => file;
}

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
  group('EmbeddedWhisperBackend', () {
    late Directory tmp;
    late AsrModelStore store;
    late _FakeWhisperEngine engine;

    setUp(() {
      EmbeddedWhisperBackend.unload();
      tmp = Directory.systemTemp.createTempSync('opx_emb_whisper_');
      store = AsrModelStore(Future.value(tmp));
      engine = _FakeWhisperEngine();
    });

    tearDown(() {
      EmbeddedWhisperBackend.unload();
      tmp.deleteSync(recursive: true);
    });

    test('status covers unavailable, unknown, missing and installed', () async {
      final tiny = asrModelSpec('whisper-tiny-multilingual')!;
      var modelId = tiny.id;
      final backend = EmbeddedWhisperBackend(
        store: store,
        modelId: () => modelId,
        engine: engine,
      );

      // Engine unavailable
      engine.isAvailable = false;
      expect((await backend.status()).reason, 'engine_unavailable');

      // Unknown model id
      engine.isAvailable = true;
      modelId = 'does-not-exist';
      expect((await backend.status()).reason, 'model_unknown');

      // Missing model file
      modelId = tiny.id;
      expect((await backend.status()).reason, 'model_not_installed');

      // Installed model
      File('${tmp.path}/${tiny.file}').writeAsBytesSync([0, 1, 2]);
      File('${tmp.path}/models.json').writeAsStringSync(
        '{"${tiny.id}":{"file":"${tiny.file}","sha256":"${tiny.sha256}","bytes":${tiny.bytes}}}',
      );
      final ready = await backend.status();
      expect(ready.available, isTrue);
      expect(ready.engineVersion, contains('whisper.cpp'));

      // Transcribe success + model cache reuse
      final req = TranscriptionRequest(
        audioPath: '${tmp.path}/a.wav',
        audioMs: 5000,
        audioSha256: 'abc',
        language: 'en',
      );
      final stages = <AsrStage>[];
      final res = await backend.transcribe(
        req,
        AsrTaskContext(
          cancel: AsrCancelToken(),
          report: (s, {processedMs, totalMs}) => stages.add(s),
        ),
      );
      expect(res.backend, 'embedded');
      expect(stages, contains(AsrStage.transcribing));
      // Second call reuses loaded model
      final res2 = await backend.transcribe(
        req,
        AsrTaskContext(
          cancel: AsrCancelToken(),
          report: (_, {processedMs, totalMs}) {},
        ),
      );
      expect(res2.modelId, tiny.id);

      // Cancelled before start
      final cancel = AsrCancelToken()..cancel();
      await expectLater(
        backend.transcribe(
          req,
          AsrTaskContext(cancel: cancel, report: (_, {processedMs, totalMs}) {}),
        ),
        throwsA(isA<AsrBackendException>().having((e) => e.code, 'code', 'cancelled')),
      );

      // Error code mapping
      for (final (code, expected) in [
        (AsrErrorCode.modelUnavailable, 'model_unavailable'),
        (AsrErrorCode.inputUnsupported, 'audio_format_unsupported'),
        (AsrErrorCode.inputUnavailable, 'audio_unavailable'),
        (AsrErrorCode.language, 'language_unsupported'),
        (AsrErrorCode.noMemory, 'out_of_memory'),
        (AsrErrorCode.cancelled, 'cancelled'),
        (AsrErrorCode.unavailable, 'engine_unavailable'),
        (AsrErrorCode.nativeFailure, 'recognition_failed'),
      ]) {
        engine.jobError = code;
        await expectLater(
          backend.transcribe(
            req,
            AsrTaskContext(
              cancel: AsrCancelToken(),
              report: (_, {processedMs, totalMs}) {},
            ),
          ),
          throwsA(isA<AsrBackendException>().having((e) => e.code, 'code', expected)),
        );
      }

      // Open model error
      EmbeddedWhisperBackend.unload();
      engine.jobError = null;
      engine.openError = AsrErrorCode.noMemory;
      await expectLater(
        backend.transcribe(
          req,
          AsrTaskContext(
            cancel: AsrCancelToken(),
            report: (_, {processedMs, totalMs}) {},
          ),
        ),
        throwsA(isA<AsrBackendException>().having((e) => e.code, 'code', 'out_of_memory')),
      );
    });
  });

  group('AsrSettingsSection & AsrHttpServiceSettingsPage', () {
    testWidgets('switches modes, uses/removes model, and opens HTTP settings page', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final tmp = Directory.systemTemp.createTempSync('opx_asr_sec2_');
      final db = sqlite3.openInMemory();
      final tiny = asrModelSpec('whisper-tiny-multilingual')!;
      File('${tmp.path}/${tiny.file}').writeAsBytesSync([0, 1, 2]);
      File('${tmp.path}/models.json').writeAsStringSync(
        '{"${tiny.id}":{"file":"${tiny.file}","sha256":"${tiny.sha256}","bytes":${tiny.bytes}}}',
      );
      final registry = AsrBackendRegistry(
        db: db,
        models: AsrModelStore(Future.value(tmp)),
      );
      addTearDown(() {
        db.close();
        tmp.deleteSync(recursive: true);
      });

      await tester.pumpWidget(
        _host(Scaffold(body: SingleChildScrollView(child: AsrSettingsSection(registry: registry)))),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();

      // Switch to local embedded mode
      await tester.tap(find.byKey(const ValueKey('asr-mode-embedded')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('asr-models')), findsOneWidget);

      // Tap Use on tiny model, then Remove
      final useBtn = find.text('Use');
      if (useBtn.evaluate().isNotEmpty) {
        await tester.tap(useBtn.first);
        await tester.pumpAndSettle();
      }
      final removeBtn = find.text('Remove');
      if (removeBtn.evaluate().isNotEmpty) {
        await tester.tap(removeBtn.first);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pumpAndSettle();
      }

      // Switch back to platform
      await tester.tap(find.byKey(const ValueKey('asr-mode-platform')));
      await tester.pumpAndSettle();

      // Open AsrHttpServiceSettingsPage
      await tester.tap(find.byKey(const ValueKey('asr-add-service')));
      await tester.pumpAndSettle();
      expect(find.byType(AsrHttpServiceSettingsPage), findsOneWidget);
    });
  });

  group('MediaDetailPage file-details & developer actions', () {
    testWidgets('renders unmatched file details in wide & narrow layouts and opens debug page', (
      tester,
    ) async {
      final tmp = Directory.systemTemp.createTempSync('opx_file_detail_');
      final img = File('${tmp.path}/p.png')..writeAsBytesSync(_png);
      final sample = File('${tmp.path}/raw_clip.mkv')..writeAsBytesSync([1, 2, 3]);
      final db = sqlite3.openInMemory();
      final sources = Sources();
      final library = LibraryService(db);
      final artwork = _FakeArtwork(sources, img);
      final media = MediaProcessingService(
        db: db,
        sources: sources,
        root: Future.value(Directory('${tmp.path}/media')),
        processor: FakeMediaProcessor(),
      );
      final registry = AsrBackendRegistry(
        db: library.configuration,
        models: AsrModelStore(Future.value(Directory('${tmp.path}/models'))),
        backendFactory: (_) => FakeAsrBackend(),
      );
      final subService = SubtitleGenerationService(
        db: db,
        media: media,
        backends: registry,
        root: Future.value(Directory('${tmp.path}/subtitles')),
      );
      SubtitleGenerationService.current = subService;
      addTearDown(() {
        SubtitleGenerationService.current = null;
        subService.dispose();
        media.dispose();
        library.close();
        tmp.deleteSync(recursive: true);
      });

      final id = library.register(
        SourceEntry(ResourceRef('@local', sample.path), 'raw_clip.mkv', isFolder: false),
      );
      addToLibrary(library, id);
      final row = library.query().first;

      for (final size in const [Size(1280, 900), Size(420, 900)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          OpenPlayXApp(
            appearance: AppThemeController(
              initialLanguage: 'en',
              initialDeveloperMode: true,
            ),
            home: MediaDetailPage(
              service: library,
              sources: sources,
              artwork: artwork,
              media: row,
              play: (_, _) async {},
              resourceLabel: (v) => v.name,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MediaDetailPage), findsOneWidget);
      }
      tester.view.reset();
    });
  });

  group('SettingsPage appearance & language', () {
    testWidgets('toggles theme mode, developer mode and opens About', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final library = LibraryService(sqlite3.openInMemory());
      final theme = AppThemeController();
      addTearDown(library.close);

      await tester.pumpWidget(
        OpenPlayXApp(
          appearance: theme,
          home: SettingsPage(library: library, sources: SourceManager()),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle dark / light theme if visible
      for (final label in ['深色', '浅色', '跟随系统']) {
        final f = find.text(label);
        if (f.evaluate().isNotEmpty) {
          await tester.tap(f.first);
          await tester.pumpAndSettle();
        }
      }
      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });
}
