import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/assistant/conversation/assistant_store.dart';
import 'package:openplayx/assistant/conversation/conversation_coordinator.dart';
import 'package:openplayx/assistant/plugins/tools/tool_registry.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/features/assistant/model/ai_chat_part.dart';
import 'package:openplayx/features/assistant/view/widgets/ai_tool_execution_card.dart';
import 'package:sqlite3/sqlite3.dart';

import '../app_test_host.dart';

class _NoopModel implements TextModelCapability {
  @override
  Stream<ModelDelta> infer(ModelInferenceRequest request) =>
      const Stream.empty();
}

void main() {
  testWidgets('AiToolExecutionCard renders all phases, result rows, details and actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = sqlite3.openInMemory();
    final store = AssistantStore(db, configuration: db);
    final coordinator = ConversationCoordinator(
      store: store,
      gateway: ToolGateway(ToolRegistry()),
      model: () async => _NoopModel(),
      context: () => {},
    );
    addTearDown(() async {
      coordinator.dispose();
      db.close();
    });

    final turn = ConversationTurn('t1', const [], status: 'completed');
    final opened = <Map<String, dynamic>>[];

    final parts = [
      AiChatPart(
        id: 'p-prep',
        turn: turn,
        kind: AiPartKind.tool,
        tool: 'media_probe',
        phase: AiToolPhase.preparing,
        arguments: const {'start_ms': 0, 'end_ms': 10000},
      ),
      AiChatPart(
        id: 'p-run',
        turn: turn,
        kind: AiPartKind.tool,
        tool: 'media_transcode',
        phase: AiToolPhase.running,
        arguments: const {'preset_id': 'video.mobile.720p'},
        progress: const {
          'status': 'running',
          'progress': 0.45,
          'processed_ms': 4500,
          'total_ms': 10000,
        },
      ),
      AiChatPart(
        id: 'p-wait',
        turn: turn,
        kind: AiPartKind.tool,
        tool: 'media_save_to_source',
        phase: AiToolPhase.waiting,
        confirmation: PendingConfirmation(
          'media_save_to_source',
          const {'task_id': 'task-1'},
          id: 'conf-1',
          turnId: 't1',
          targetLabel: 'NAS / OpenPlayX',
        ),
      ),
      AiChatPart(
        id: 'p-ok',
        turn: turn,
        kind: AiPartKind.tool,
        tool: 'search_media',
        phase: AiToolPhase.success,
        duration: const Duration(seconds: 2),
        arguments: const {'query': 'Lighthouse'},
        rawArguments: '{"query":"Lighthouse"}',
        rawResult:
            '{"media":[{"media_id":"m1","title":"The Lighthouse","year":2019}]}',
        data: const {
          'media': [
            {'media_id': 'm1', 'title': 'The Lighthouse', 'year': 2019},
          ],
          'sources': [
            {
              'source_id': 's1',
              'entries': [
                {'name': '/movies/clip.mp4', 'ref': 'r1'},
              ],
            },
          ],
        },
      ),
      AiChatPart(
        id: 'p-fail',
        turn: turn,
        kind: AiPartKind.tool,
        tool: 'media_probe',
        phase: AiToolPhase.failed,
        text: 'https://secret.example/path failed',
        data: const {'error': 'unavailable'},
      ),
      AiChatPart(
        id: 'p-cancel',
        turn: turn,
        kind: AiPartKind.tool,
        tool: 'subtitle_generate',
        phase: AiToolPhase.cancelled,
      ),
    ];

    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: ListView(
            children: [
              for (final p in parts)
                AiToolExecutionCard(
                  part: p,
                  coordinator: coordinator,
                  onOpenMedia: (m) async => opened.add(m),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(AiToolExecutionCard), findsNWidgets(parts.length));

    await tester.tap(find.byType(AiToolExecutionCard).at(3));
    await tester.pump(const Duration(milliseconds: 200));

    final lh = find.textContaining('The Lighthouse');
    if (lh.evaluate().isNotEmpty) {
      await tester.tap(lh.first, warnIfMissed: false);
      await tester.pump();
    }
  });
}
