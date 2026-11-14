import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx/app/app_shell.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/configuration/source_configuration_service.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/features/ai_assistant/ai_chat_view.dart';
import 'package:openplayx/features/player/player_page.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:openplayx_playback/playback.dart';
import 'package:sqlite3/sqlite3.dart';

import '../test/app_test_host.dart';
import 'support/test_video.dart';

class _OpenMovie implements TextModelCapability {
  _OpenMovie(this.resource);
  final String resource;
  var requests = 0;
  @override
  Stream<ModelDelta> infer(ModelInferenceRequest request) async* {
    if (requests++ == 0) {
      yield ModelToolDelta(
        ModelToolCall(
          'open',
          'playback_open',
          jsonEncode({'resource_id': resource}),
        ),
      );
      yield const ModelCompleted('toolCalls');
    } else {
      yield const ModelTextDelta('正在播放测试视频。');
      yield const ModelCompleted('stop');
    }
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Route transitions and native video must render while awaiting IO, just
  // as they do in the normal app (not only on explicit tester.pump calls).
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('AI open reveals the mobile player and native video advances', (
    tester,
  ) async {
    final dir = await Directory.systemTemp.createTemp('opx-mobile-ai-');
    final file = await createTestVideo(dir);
    final library = LibraryService(sqlite3.openInMemory());
    final configuration = SourceConfigurationService(sqlite3.openInMemory());
    final sources = SourceManager(configuration: configuration);
    final backend = LibVlcBackend();
    final media = library.register(
      SourceEntry(
        ResourceRef('@local', file.path),
        'Native navigation fixture',
        isFolder: false,
      ),
    );
    final model = _OpenMovie(library.resources(media).single['id'] as String);
    try {
      await tester.pumpWidget(
        TestApp(
          home: AppShell(
            library: library,
            sources: sources,
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
      await tester.tap(composer);
      await tester.pump(const Duration(milliseconds: 300));
      chat.controller!.draft.text = '播放测试视频';
      final pending = chat.controller!.send(toolsEnabled: true);
      for (var i = 0; i < 150; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (backend.value.status == PlaybackStatus.playing &&
            backend.value.position > const Duration(seconds: 1) &&
            find.byType(AiChatView).evaluate().isEmpty) {
          break;
        }
      }
      await pending;
      debugPrint(
        'MOBILE_FLOW: requests=${model.requests} sendError=${chat.controller!.sendError} '
        'turns=${jsonEncode(chat.coordinator.turns.map((t) => {'status': t.status, 'error': t.error, 'messages': t.messages.map((m) => m.toJson()).toList()}).toList())}',
      );
      expect(find.byType(AiChatView), findsNothing);
      expect(find.byType(PlayerPage), findsOneWidget);
      expect(backend.value.status, PlaybackStatus.playing);
      expect(backend.value.position, greaterThan(const Duration(seconds: 1)));
      expect(backend.value.videoSize, isNotNull);
      expect(tester.view.viewInsets.bottom, 0);
      expect(chat.coordinator.turns.single.status, 'completed');
      debugPrint(
        'MOBILE_PLAYER_VISIBLE: position=${backend.value.position} size=${backend.value.videoSize}',
      );
      await Future<void>.delayed(const Duration(seconds: 8));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      backend.dispose();
      await sources.dispose();
      configuration.close();
      library.close();
      await dir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
