import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/features/ai_assistant/adapters/flyer_chat_adapter.dart';
import 'package:openplayx/features/ai_assistant/models/ai_chat_part.dart';
import 'package:openplayx/services/ai_tools/tool_registry.dart';
import 'package:openplayx/services/conversations/assistant_store.dart';
import 'package:openplayx/services/conversations/conversation_coordinator.dart';
import 'package:sqlite3/sqlite3.dart';

import 'conversation_test.dart' show FakeModel;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late AssistantStore store;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = sqlite3.openInMemory();
    store = AssistantStore(db);
  });
  tearDown(() => db.close());

  test('reasoning, activity and live tool progress are visible while the '
      'turn runs, and reasoning is kept in history', () async {
    final release = Completer<void>();
    final registry = ToolRegistry()
      ..register(
        RegisteredTool('clip', 'clip', const {}, (_) async {
          ToolExecution.report({'status': 'running', 'progress': 0.5});
          await release.future;
          return {'task_id': 't1', 'status': 'succeeded'};
        }),
      );
    final model = FakeModel((request) async* {
      if (!request.messages.any((m) => m.role == 'tool')) {
        yield const ModelReasoningDelta('先看看有哪些电影');
        yield const ModelToolFragment(0, 'c1', 'clip', '{');
        yield const ModelToolDelta(ModelToolCall('c1', 'clip', '{}'));
        yield const ModelCompleted('toolCalls');
      } else {
        yield const ModelTextDelta('完成');
        yield const ModelCompleted('stop');
      }
    });
    final c = ConversationCoordinator(
      store: store,
      gateway: ToolGateway(registry),
      model: () async => model,
      context: () => {},
    );
    addTearDown(c.dispose);
    final adapter = FlyerChatAdapter(c);
    addTearDown(adapter.dispose);

    final done = c.send('截一段', toolsEnabled: true);
    // Wait until the tool reported progress.
    for (var i = 0; i < 100 && c.currentTurn?.toolProgress == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final turn = c.currentTurn!;
    expect(turn.activity, 'tool');
    expect(turn.executingTool, 'clip');
    expect(turn.step, 1);
    final parts = adapter.project();
    expect(parts.last.kind, AiPartKind.activity);
    expect(parts.last.tool, 'clip');
    expect(
      parts.where((p) => p.kind == AiPartKind.reasoning).single.text,
      '先看看有哪些电影',
    );
    final card = parts.where((p) => p.kind == AiPartKind.tool).single;
    expect(card.phase, AiToolPhase.running);
    expect(card.progress, {'status': 'running', 'progress': 0.5});

    release.complete();
    await done;
    expect(c.turns.single.status, 'completed');
    expect(c.currentTurn, isNull);
    final after = adapter.project();
    expect(after.any((p) => p.kind == AiPartKind.activity), isFalse);
    expect(
      after.where((p) => p.kind == AiPartKind.tool).single.progress,
      isNull,
    );
    // Reasoning survives a reload from history.
    final reloaded = ConversationCoordinator(
      store: store,
      gateway: ToolGateway(registry),
      model: () async => model,
      context: () => {},
    );
    addTearDown(reloaded.dispose);
    expect(
      reloaded.turns.single.messages
          .where((m) => m.reasoning.isNotEmpty)
          .single
          .reasoning,
      '先看看有哪些电影',
    );
  });

  test('a turn waiting on the model shows thinking with the tool being '
      'prepared', () async {
    final gate = StreamController<ModelDelta>();
    final c = ConversationCoordinator(
      store: store,
      gateway: ToolGateway(ToolRegistry()),
      model: () async => FakeModel((_) => gate.stream),
      context: () => {},
    );
    addTearDown(c.dispose);
    final done = c.send('hi', toolsEnabled: true);
    await Future<void>.delayed(Duration.zero);
    expect(c.currentTurn!.activity, 'thinking');
    gate.add(const ModelToolFragment(0, 'x', 'media_probe', '{"res'));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(c.currentTurn!.preparingTool, 'media_probe');
    gate.add(const ModelTextDelta('ok'));
    gate.add(const ModelCompleted('stop'));
    await gate.close();
    await done;
    expect(c.turns.single.status, 'completed');
  });
}
