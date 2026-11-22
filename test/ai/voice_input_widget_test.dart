import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/assistant/conversation/assistant_store.dart';
import 'package:openplayx/assistant/conversation/conversation_coordinator.dart';
import 'package:openplayx/assistant/plugins/tools/tool_registry.dart';
import 'package:openplayx/assistant/voice/voice_settings.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/features/assistant/controller/ai_chat_controller.dart';
import 'package:openplayx/features/assistant/view/widgets/ai_composer.dart';
import 'package:openplayx/features/assistant/view/voice_settings_section.dart';
import 'package:openplayx/ui/components/forms/secret_input.dart';
import 'package:openplayx/ui/components/forms/settings_text_input.dart';
import 'package:sqlite3/sqlite3.dart';

import 'chat_frontend_test.dart' show host;
import 'conversation_test.dart' show FakeModel;
import 'voice_input_test.dart'
    show MemoryVoiceSecrets, FakeVoiceRecorder, FakeVoiceTranscriber;

void main() {
  late Database db, configuration;
  late AssistantStore store;
  late VoiceSettings settings;
  late FakeVoiceRecorder recorder;
  late FakeVoiceTranscriber transcriber;
  late FakeModel model;
  late ConversationCoordinator coordinator;
  late AiChatController chat;

  setUp(() async {
    db = sqlite3.openInMemory();
    configuration = sqlite3.openInMemory();
    store = AssistantStore(db, configuration: configuration);
    settings = VoiceSettings(configuration, secrets: MemoryVoiceSecrets());
    await settings.save(const VoiceConfig(), 'mock-key');
    recorder = FakeVoiceRecorder();
    transcriber = FakeVoiceTranscriber();
    model = FakeModel((_) async* {
      yield const ModelCompleted('stop');
    });
    coordinator = ConversationCoordinator(
      store: store,
      gateway: ToolGateway(ToolRegistry(), journal: store),
      model: () async => model,
      context: () => {'page': 'library'},
    );
    chat = AiChatController(
      coordinator,
      voiceRecorder: recorder,
      voiceTranscriber: transcriber,
      voiceSettings: settings,
    );
  });
  tearDown(() {
    chat.dispose();
    coordinator.dispose();
    store.close();
    db.close();
    configuration.close();
  });

  Widget composer() => host(
    AiComposer(controller: chat, toolsEnabled: () => true, onSettings: () {}),
  );

  testWidgets('click start and stop, review transcript, then send manually', (
    tester,
  ) async {
    chat.draft.text = 'draft';
    await tester.pumpWidget(composer());
    await tester.tap(find.byTooltip('Start voice input'));
    await tester.pump();
    // The text field is replaced by the recording bar with a live timer.
    expect(find.byKey(const ValueKey('ai-composer-input')), findsNothing);
    expect(find.text('0:00'), findsOneWidget);
    recorder.levelController
      ..add(0.9)
      ..add(0.02);
    await tester.pump(const Duration(seconds: 2));
    expect(chat.voice.levels.value, [0.9, 0.02]);
    expect(transcriber.calls, 0);
    await tester.tap(find.byTooltip('Stop and transcribe'));
    await tester.pump();
    expect(chat.draft.text, 'draft\nrecognized words');
    expect(store.draft, chat.draft.text);
    expect(model.requests, isEmpty);
    final input = find.descendant(
      of: find.byKey(const ValueKey('ai-composer-input')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(input, 'edited transcript');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(model.requests, hasLength(1));
    expect(chat.draft.text, isEmpty);
  });

  testWidgets('send while recording transcribes and sends directly', (
    tester,
  ) async {
    await tester.pumpWidget(composer());
    await tester.tap(find.byTooltip('Start voice input'));
    await tester.pump();
    await tester.tap(find.byTooltip('Transcribe and send'));
    await tester.pump();
    await tester.pump();
    expect(transcriber.calls, 1);
    expect(model.requests, hasLength(1));
    expect(chat.draft.text, isEmpty);
    expect(find.byKey(const ValueKey('ai-composer-input')), findsOneWidget);
  });

  testWidgets(
    'shows transcribing state, blocks duplicate clicks and supports cancel',
    (tester) async {
      transcriber.pending = Completer<String>();
      chat.draft.text = 'keep me';
      await tester.pumpWidget(composer());
      await tester.tap(find.byTooltip('Start voice input'));
      await tester.pump();
      await tester.tap(find.byTooltip('Stop and transcribe'));
      await tester.pump();
      expect(find.text('Transcribing…'), findsOneWidget);
      // Mic is hidden and stop/send are disabled until transcription ends.
      expect(find.byTooltip('Start voice input'), findsNothing);
      await tester.tap(
        find.byTooltip('Transcribe and send'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(recorder.starts, 1);
      expect(transcriber.calls, 1);
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pump();
      transcriber.pending!.complete('discarded words');
      await tester.pump();
      expect(chat.draft.text, 'keep me');
      expect(model.requests, isEmpty);
    },
  );

  testWidgets('recording limit discards audio without uploading', (
    tester,
  ) async {
    chat.draft.text = 'keep me';
    await tester.pumpWidget(composer());
    await tester.tap(find.byTooltip('Start voice input'));
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    expect(transcriber.calls, 0);
    expect(recorder.cancellations, 1);
    expect(chat.draft.text, 'keep me');
    expect(chat.voice.busy, false);
  });

  testWidgets('unsupported platform displays feedback and retains draft', (
    tester,
  ) async {
    recorder.supported = false;
    chat.draft.text = 'keep me';
    await tester.pumpWidget(composer());
    await tester.tap(find.byTooltip('Start voice input'));
    await tester.pump();
    expect(
      find.textContaining('not supported on this platform'),
      findsOneWidget,
    );
    expect(chat.draft.text, 'keep me');
    expect(recorder.starts, 0);
  });

  testWidgets(
    'switching conversation cancels recording and keeps both drafts',
    (tester) async {
      chat.draft.text = 'first draft';
      final firstId = coordinator.conversationId;
      await tester.pumpWidget(composer());
      await tester.tap(find.byTooltip('Start voice input'));
      await tester.pump();
      coordinator.newConversation();
      await tester.pump();
      expect(recorder.cancellations, 1);
      expect(chat.draft.text, isEmpty);
      coordinator.selectConversation(firstId);
      await tester.pump();
      expect(chat.draft.text, 'first draft');
      expect(model.requests, isEmpty);
    },
  );

  testWidgets('voice settings save separately with a masked key', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SingleChildScrollView(child: VoiceSettingsSection(settings: settings)),
      ),
    );
    await tester.pump();
    final fields = find.byType(SettingsTextInput);
    await tester.enterText(
      find.descendant(of: fields.at(0), matching: find.byType(EditableText)),
      'https://transcription.example/v1/audio/transcriptions',
    );
    await tester.enterText(
      find.descendant(of: fields.at(1), matching: find.byType(EditableText)),
      'independent-model',
    );
    final secretField = find.descendant(
      of: find.byType(SecretInput),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(secretField).obscureText, true);
    await tester.enterText(secretField, 'new-mock-key');
    final save = find.byKey(const ValueKey('voice-settings-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(settings.load().endpoint, 'https://transcription.example/v1');
    expect(settings.load().model, 'independent-model');
    expect(await settings.key(), 'new-mock-key');
    expect(store.loadConfig().usePlatform, true);
  });
  testWidgets(
    'voice mode tabs browse until enabled and keep local configuration',
    (tester) async {
      await tester.pumpWidget(
        host(
          SingleChildScrollView(
            child: VoiceSettingsSection(settings: settings),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(settings.load().usePlatform, false);
      await tester.tap(find.byKey(const ValueKey('voice-tab-cloud')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsTextInput), findsNothing);
      expect(settings.load().usePlatform, false);
      await tester.tap(find.byKey(const ValueKey('voice-settings-save')));
      await tester.pumpAndSettle();
      expect(settings.load().usePlatform, true);
      expect(await settings.key(), 'mock-key');
      await tester.tap(find.byKey(const ValueKey('voice-tab-local')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsTextInput), findsNWidgets(2));
      expect(settings.load().usePlatform, true);
      await tester.ensureVisible(
        find.byKey(const ValueKey('voice-settings-save')),
      );
      await tester.tap(find.byKey(const ValueKey('voice-settings-save')));
      await tester.pumpAndSettle();
      expect(settings.load().usePlatform, false);
      expect(await settings.key(), 'mock-key');
    },
  );

  testWidgets('fresh voice settings hide key fields in default cloud mode', (
    tester,
  ) async {
    configuration.execute(
      "DELETE FROM settings WHERE namespace='assistant' AND key='voice'",
    );
    await tester.pumpWidget(
      host(
        SingleChildScrollView(child: VoiceSettingsSection(settings: settings)),
      ),
    );
    await tester.pumpAndSettle();
    expect(settings.load().usePlatform, true);
    expect(find.byType(SettingsTextInput), findsNothing);
    expect(find.byType(SecretInput), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
