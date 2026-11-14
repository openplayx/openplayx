import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/app/app_shell.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/features/ai_assistant/ai_chat_view.dart';
import 'package:openplayx/features/player/player_page.dart';
import 'package:openplayx/services/conversations/assistant_store.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:sqlite3/sqlite3.dart';

import '../app_test_host.dart';
import '../features/library/library_page_test.dart' show Sources;
import '../features/player/player_page_test.dart' show FakeBackend;

class _PlaybackModel implements TextModelCapability {
  _PlaybackModel(this.resource);
  final String resource;
  final continueAfterOpen = Completer<void>();
  final requests = <ModelInferenceRequest>[];

  @override
  Stream<ModelDelta> infer(ModelInferenceRequest request) async* {
    requests.add(request);
    switch (requests.length) {
      case 1:
        yield ModelToolDelta(
          ModelToolCall(
            'open',
            'playback_open',
            jsonEncode({'resource_id': resource}),
          ),
        );
        yield const ModelCompleted('toolCalls');
      case 2:
        await continueAfterOpen.future;
        yield const ModelToolDelta(
          ModelToolCall('state', 'playback_get', '{}'),
        );
        yield const ModelCompleted('toolCalls');
      default:
        yield const ModelTextDelta('正在播放。');
        yield const ModelCompleted('stop');
    }
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '${platform.name}: AI playback reveals player, dismisses keyboard and continues tools',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final library = LibraryService(sqlite3.openInMemory());
        final file = File('test/fixtures/test_video.mp4').absolute;
        final media = library.register(
          SourceEntry(
            ResourceRef('@local', file.path),
            'Test movie',
            isFolder: false,
          ),
        );
        final model = _PlaybackModel(
          library.resources(media).single['id'] as String,
        );
        final backend = FakeBackend();
        await AssistantStore(
          library.db,
          configuration: library.configuration,
        ).saveConfig(const AssistantConfig(), 'test-key');
        await tester.pumpWidget(
          TestApp(
            home: AppShell(
              library: library,
              sources: Sources(),
              backend: backend,
              assistantModel: () async => model,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('AI 助手'));
        await tester.pumpAndSettle();
        final chat = tester.widget<AiChatView>(find.byType(AiChatView));
        final composer = find.descendant(
          of: find.byKey(const ValueKey('ai-composer-input')),
          matching: find.byType(EditableText),
        );
        await tester.showKeyboard(composer);
        await tester.enterText(composer, '帮我播放这部电影');
        expect(tester.testTextInput.isVisible, true);
        final pending = chat.controller!.send(
          toolsEnabled: chat.toolsEnabled(),
        );
        try {
          for (var i = 0; i < 15; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 100));
            if (model.requests.length >= 2 &&
                find.byType(AiChatView).evaluate().isEmpty) {
              break;
            }
          }
          expect(
            backend.opened,
            [file.uri],
            reason: jsonEncode(
              chat.coordinator.turns
                  .map((t) => t.messages.map((m) => m.toJson()).toList())
                  .toList(),
            ),
          );
          expect(
            find.byType(AiChatView),
            findsNothing,
            reason: 'The chat route must not cover the embedded mobile player.',
          );
          expect(find.byType(PlayerPage), findsOneWidget);
          expect(tester.testTextInput.isVisible, false);
          expect(
            chat.coordinator.busy,
            true,
            reason:
                'Closing the chat must not cancel the remaining tool workflow.',
          );
          model.continueAfterOpen.complete();
          await pending;
          await tester.pump(const Duration(milliseconds: 500));
          final turn = chat.coordinator.turns.single;
          expect(turn.status, 'completed', reason: turn.error);
          final state = jsonDecode(
            turn.messages.firstWhere((m) => m.callId == 'state').text,
          ) as Map;
          expect(state['status'], 'success');
          expect(state['data']['status'], 'playing');
          expect(state['data']['session_id'], isNotNull);
          expect(tester.takeException(), isNull);
        } finally {
          if (!model.continueAfterOpen.isCompleted) {
            model.continueAfterOpen.complete();
          }
          chat.coordinator.stop();
          await pending;
          await tester.pumpWidget(const SizedBox.shrink());
          library.close();
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
