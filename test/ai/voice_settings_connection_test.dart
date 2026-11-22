import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/assistant/voice/voice_service.dart';
import 'package:openplayx/assistant/voice/voice_settings.dart';
import 'package:openplayx/data/configuration/configuration_database.dart';
import 'package:openplayx/features/assistant/view/voice_settings_section.dart';
import 'package:openplayx/l10n/generated/app_localizations.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:sqlite3/sqlite3.dart';

import '../app_test_host.dart';
import 'voice_input_test.dart' show MemoryVoiceSecrets;

void main() {
  for (final width in [390.0, 1100.0]) {
    testWidgets('tests unsaved voice configuration without saving at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = sqlite3.openInMemory();
      ConfigurationDatabase.initialize(db);
      final secrets = MemoryVoiceSecrets();
      final settings = VoiceSettings(db, secrets: secrets);
      await settings.save(const VoiceConfig(), 'saved-key');
      final pending = Completer<void>();
      var calls = 0;
      VoiceConfig? captured;
      String? capturedKey;
      await tester.pumpWidget(
        TestApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VoiceSettingsSection(
                settings: settings,
                testConnection: (config, key) {
                  calls++;
                  captured = config;
                  capturedKey = key;
                  return pending.future;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder input(String key) => find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(EditableText),
      );
      await tester.enterText(
        input('voice-settings-endpoint'),
        'https://draft.example/v1/audio/transcriptions/',
      );
      await tester.enterText(input('voice-settings-model'), 'draft-whisper');
      await tester.enterText(input('voice-settings-key'), 'draft-key');
      final test = find.byKey(const ValueKey('voice-settings-test'));
      await tester.ensureVisible(test);
      await tester.tap(test);
      await tester.pump();
      expect(calls, 1);
      expect(captured!.endpoint, 'https://draft.example/v1');
      expect(captured!.model, 'draft-whisper');
      expect(capturedKey, 'draft-key');
      expect(tester.widget<ShadButton>(test).onPressed, isNull);
      expect(
        tester
            .widget<ShadButton>(
              find.byKey(const ValueKey('voice-settings-save')),
            )
            .onPressed,
        isNull,
      );
      expect(settings.load().model, 'whisper-1');
      expect(await settings.key(), 'saved-key');
      pending.complete();
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(VoiceSettingsSection)),
      );
      expect(find.text(l.voiceConnectionOk), findsOneWidget);
      await tester.enterText(input('voice-settings-model'), 'changed-again');
      await tester.pump();
      expect(find.text(l.voiceConnectionOk), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      db.close();
    });
  }

  testWidgets(
    'uses stored key when blank and displays authentication failures',
    (tester) async {
      final db = sqlite3.openInMemory();
      ConfigurationDatabase.initialize(db);
      final settings = VoiceSettings(db, secrets: MemoryVoiceSecrets());
      await settings.save(const VoiceConfig(), 'stored-key');
      String? used;
      await tester.pumpWidget(
        TestApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VoiceSettingsSection(
                settings: settings,
                testConnection: (config, key) async {
                  used = key;
                  throw const VoiceFailure('authentication');
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('voice-settings-key')),
          matching: find.byType(EditableText),
        ),
        '',
      );
      final button = find.byKey(const ValueKey('voice-settings-test'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(VoiceSettingsSection)),
      );
      expect(used, 'stored-key');
      expect(find.text(l.aiAuthenticationFailed), findsOneWidget);
      expect(await settings.key(), 'stored-key');
      await tester.pumpWidget(const SizedBox());
      db.close();
    },
  );
}
