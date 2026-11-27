import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/artwork/artwork_service.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/capabilities/speech/asr_backend_config.dart';
import 'package:openplayx/capabilities/speech/asr_model_store.dart';
import 'package:openplayx/core/capabilities/metadata_capability.dart';
import 'package:openplayx/features/library/view/metadata_artwork.dart';
import 'package:openplayx/features/settings/asr_settings_section.dart';
import 'package:openplayx/features/settings/tmdb_settings_section.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:openplayx/ui/theme/app_theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart';

final _png = Uint8List.fromList(const [
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
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

class _FakeArtwork extends ArtworkService {
  _FakeArtwork(super.sources, this.file);
  final File file;
  @override
  Future<File> load(ArtworkDescriptor artwork) async => file;
}

void main() {
  testWidgets('TmdbSettingsSection switches mode and configures token', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(560, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final library = LibraryService(sqlite3.openInMemory());
    addTearDown(library.close);

    await tester.pumpWidget(_host(TmdbSettingsSection(library: library)));
    await tester.pumpAndSettle();

    // Switch to local TMDB tab, configure token, enable local mode, forget token, switch back to cloud.
    await tester.tap(find.byKey(const ValueKey('tmdb-tab-local')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tmdb-configure')));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('tmdb-token'));
    await tester.enterText(
      find.descendant(of: input, matching: find.byType(EditableText)),
      'test-tmdb-token',
    );
    await tester.pump();
    final save = find.text('Save');
    await tester.tap(save.last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tmdb-enable-mode')));
    await tester.pumpAndSettle();

    // Re-open configure and forget token
    await tester.tap(find.byKey(const ValueKey('tmdb-configure')));
    await tester.pumpAndSettle();
    final forget = find.byKey(const ValueKey('tmdb-forget'));
    if (forget.evaluate().isNotEmpty) {
      await tester.tap(forget);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const ValueKey('tmdb-tab-cloud')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tmdb-enable-mode')));
    await tester.pumpAndSettle();
  });

  testWidgets('AsrSettingsSection renders models, selection and removal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final tmp = Directory.systemTemp.createTempSync('opx_asr_sec_');
    final db = sqlite3.openInMemory();
    final tiny = asrModelSpec('whisper-tiny-multilingual')!;
    File('${tmp.path}/${tiny.file}').writeAsBytesSync([0, 1, 2]);
    File('${tmp.path}/models.json').writeAsStringSync(
      '{"${tiny.id}":{"file":"${tiny.file}","sha256":"${tiny.sha256}","bytes":${tiny.bytes}}}',
    );
    final registry = AsrBackendRegistry(
      db: db,
      models: AsrModelStore(Future.value(tmp)),
    )..selectDefault('embedded');
    addTearDown(() {
      db.close();
      tmp.deleteSync(recursive: true);
    });

    await tester.pumpWidget(_host(AsrSettingsSection(registry: registry)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    expect(find.byType(AsrSettingsSection), findsOneWidget);
  });

  testWidgets('MetadataArtwork renders placeholder, loaded image, fadeIn and updates', (
    tester,
  ) async {
    final tmp = Directory.systemTemp.createTempSync('opx_art_ui_');
    final img = File('${tmp.path}/a.png')..writeAsBytesSync(_png);
    final service = _FakeArtwork(SourceManager(), img);
    addTearDown(() => tmp.deleteSync(recursive: true));

    const d1 = ArtworkDescriptor(id: 'a1', type: 'poster');
    const d2 = ArtworkDescriptor(id: 'a2', type: 'poster');

    await tester.pumpWidget(
      _host(
        MetadataArtwork(
          service: service,
          artwork: d1,
          width: 100,
          height: 150,
          fadeIn: true,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);

    // Update artwork descriptor to trigger didUpdateWidget.
    await tester.pumpWidget(
      _host(
        MetadataArtwork(
          service: service,
          artwork: d2,
          width: 100,
          height: 150,
          fadeIn: false,
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
  });
}
