import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/library/library_service.dart';
import 'package:openplayx/capabilities/speech/asr_backend_config.dart';
import 'package:openplayx/capabilities/speech/asr_model_store.dart';
import 'package:openplayx/features/settings/asr_http_service_settings_page.dart';
import 'package:openplayx/features/settings/asr_settings_section.dart';
import 'package:openplayx/features/settings/settings_page.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../app_test_host.dart';

void main() {
  for (final width in [390.0, 1100.0]) {
    testWidgets(
      'subtitles opens recognition then HTTP service page at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final db = sqlite3.openInMemory();
        final library = LibraryService(db);
        final registry = AsrBackendRegistry(
          db: library.configuration,
          models: AsrModelStore(Future.value(null)),
        );
        await tester.pumpWidget(TestApp(home: SettingsPage(library: library)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('settings-subtitles')));
        await tester.pumpAndSettle();
        expect(find.byType(AsrSettingsSection), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('settings-speech-recognition')),
        );
        await tester.pumpAndSettle();
        expect(registry.defaultBackendId, 'platform');
        for (final mode in ['platform', 'embedded', 'http']) {
          expect(find.byKey(ValueKey('asr-mode-$mode')), findsOneWidget);
        }
        await tester.tap(find.byKey(const ValueKey('asr-mode-embedded')));
        await tester.pumpAndSettle();
        expect(registry.defaultBackendId, 'embedded');
        expect(find.byKey(const ValueKey('asr-models')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('asr-mode-platform')));
        await tester.pumpAndSettle();
        expect(registry.defaultBackendId, 'platform');
        expect(find.byKey(const ValueKey('asr-models')), findsNothing);
        final add = find.byKey(const ValueKey('asr-add-service'));
        await tester.ensureVisible(add);
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(find.byType(AsrHttpServiceSettingsPage), findsOneWidget);
        expect(find.byType(ShadDialog), findsNothing);
        final l = AppLocalizations.of(
          tester.element(find.byType(AsrHttpServiceSettingsPage)),
        );
        final save = find.byKey(const ValueKey('asr-service-save'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text(l.asrServiceUrlInvalid), findsOneWidget);
        expect(registry.list().where((c) => c.kind == 'http'), isEmpty);
        final url = find.descendant(
          of: find.byKey(const ValueKey('asr-service-url')),
          matching: find.byType(EditableText),
        );
        await tester.ensureVisible(url);
        await tester.enterText(url, 'https://asr.example.com');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.byType(AsrHttpServiceSettingsPage), findsNothing);
        expect(
          registry.list().where((c) => c.kind == 'http').single.url,
          'https://asr.example.com',
        );
        expect(
          registry.defaultBackendId,
          registry.list().where((c) => c.kind == 'http').single.id,
        );
        expect(registry.get(registry.defaultBackendId)!.protocol, 'openai');
        expect(find.text('asr.example.com'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
