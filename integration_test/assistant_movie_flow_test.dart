// Opt-in acceptance test against the user's saved model, SMB source, FFmpeg,
// local whisper and player. Creates a clip in the source's OpenPlayX folder.
// flutter drive --driver=test_driver/integration_test.dart \
//   --target=integration_test/assistant_movie_flow_test.dart -d macos \
//   --dart-define=LIVE_ASSISTANT_FLOW=true
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/app/player_window.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/features/ai_assistant/ai_chat_view.dart';
import 'package:openplayx/ui/adaptive/assistant_action.dart';

const movieFlowPrompt =
    '从 SMB 的 movie 共享里随便挑一部电影（不要总选第一个），用 media_probe 看时长，'
    '在 10%-80% 之间选起点截取 60 秒，用 media_transcode 生成子视频，'
    '完成后用 media_save_to_source 存回 SMB，'
    '对存回去的子视频用 subtitle_generate（本地识别）生成字幕并用 subtitle_save 保存，'
    '然后用 playback_open 打开这个子视频，再用 playback_set_subtitle 选上刚保存的字幕。'
    '每一步以工具结果为准；任务还没完成就告诉我进度并停下。';

Future<void> main([List<String> args = const []]) async {
  // Desktop child engines use this same entrypoint; run their real player.
  if (await runPlayerWindowIfRequested(args)) return;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'saved configuration completes SMB clip, local subtitles and playback',
    (tester) async {
      await tester.pumpWidget(const OpenPlayXApp());
      for (
        var i = 0;
        i < 300 && find.byType(AssistantAction).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final action = tester.widget<AssistantAction>(
        find.byType(AssistantAction).first,
      );
      action.onPressed();
      await tester.pumpAndSettle();
      final view = tester.widget<AiChatView>(find.byType(AiChatView).first);
      final c = view.coordinator;
      final previousConversation = c.conversationId;
      VoidCallback? traceListener;
      try {
        expect(
          view.toolsEnabled(),
          isTrue,
          reason: 'A saved negative connection probe must not silently remove all tools.',
        );
        c.newConversation();
        final seen = <String>{};
        void trace() {
          final turn = c.currentTurn ?? c.turns.lastOrNull;
          if (turn == null) return;
          for (final m in turn.messages) {
            if (m.id == null || !seen.add(m.id!)) continue;
            for (final call in m.calls) {
              debugPrint('FLOW call ${call.name} ${call.arguments}');
            }
            if (m.role == 'tool') {
              final r = jsonDecode(m.text) as Map;
              debugPrint(
                'FLOW result ${m.callId}: ${r['status']} ${r['error_code'] ?? ''} ${jsonEncode(r['data'])}',
              );
            } else if (m.role == 'assistant' && m.text.isNotEmpty) {
              debugPrint('FLOW assistant: ${m.text}');
            }
          }
        }

        traceListener = trace;
        c.addListener(trace);
        var done = false;
        // Submit through the same controller as the composer, with the exact prompt.
        view.controller!.draft.text = movieFlowPrompt;
        final flow = view.controller!
            .send(toolsEnabled: view.toolsEnabled())
            .whenComplete(() => done = true);
        final deadline = DateTime.now().add(const Duration(minutes: 25));
        while (!done && DateTime.now().isBefore(deadline)) {
          // Native window occlusion may suspend frame delivery. Model/tool
          // work and confirmations must progress independently of UI frames.
          await Future<void>.delayed(const Duration(milliseconds: 200));
          final confirmation = c.confirmation;
          if (confirmation != null) {
            // Assert outside the listener: it may run inside tester.pump's
            // async guard. Only this prompt's authorised write is approved.
            expect(confirmation.tool, 'media_save_to_source');
            c.decide(true);
          }
        }
        if (!done) c.stop();
        await flow;
        trace();
        final turn = c.turns.single;
        expect(turn.error, isNull, reason: 'FLOW status=${turn.status}');
        final calls = turn.messages.expand((m) => m.calls).toList();
        final results = {
          for (final m in turn.messages.where((m) => m.role == 'tool'))
            m.callId: jsonDecode(m.text) as Map<String, dynamic>,
        };
        const required = [
          'source_browse',
          'media_probe',
          'media_transcode',
          'media_save_to_source',
          'subtitle_generate',
          'subtitle_save',
          'playback_open',
          'playback_set_subtitle',
        ];
        for (final name in required) {
          expect(
            calls.where(
              (call) =>
                  call.name == name && results[call.id]?['status'] == 'success',
            ),
            isNotEmpty,
            reason: 'Workflow stopped before successful $name',
          );
        }
        final transcode = calls.firstWhere(
          (call) => call.name == 'media_transcode',
        );
        final range = jsonDecode(transcode.arguments) as Map;
        expect((range['end_ms'] as num) - (range['start_ms'] as num), 60000);
        final probe = calls.firstWhere(
          (call) =>
              call.name == 'media_probe' &&
              (jsonDecode(call.arguments) as Map)['resource_ref'] ==
                  range['resource_ref'],
        );
        final duration =
            (results[probe.id]!['data'] as Map)['duration_ms'] as num;
        expect(
          range['start_ms'] as num,
          inInclusiveRange(duration * .1, duration * .8),
        );
        final save = calls.firstWhere(
          (call) =>
              call.name == 'media_save_to_source' &&
              results[call.id]?['status'] == 'success',
        );
        final savedClip = results[save.id]!['data'] as Map;
        expect(savedClip['saved'], true);
        expect(savedClip['bytes'] as num, greaterThan(0));
        final generate = calls.firstWhere(
          (call) => call.name == 'subtitle_generate',
        );
        final args = jsonDecode(generate.arguments) as Map;
        expect(args['backend_id'] ?? 'embedded', 'embedded');
        expect(args['resource_ref'], savedClip['ref']);
        final open = calls.firstWhere(
          (call) =>
              call.name == 'playback_open' &&
              results[call.id]?['status'] == 'success',
        );
        expect((jsonDecode(open.arguments) as Map)['ref'], savedClip['ref']);
        final savedSubtitle = calls.firstWhere(
          (call) =>
              call.name == 'subtitle_save' &&
              results[call.id]?['status'] == 'success',
        );
        final binding =
            (results[savedSubtitle.id]!['data'] as Map)['binding_id'];
        final select = calls.firstWhere(
          (call) =>
              call.name == 'playback_set_subtitle' &&
              results[call.id]?['status'] == 'success',
        );
        final playback = results[select.id]!['data'] as Map;
        expect(playback['session_id'], isNotNull);
        expect(playback['subtitle'], {
          'kind': 'recognized',
          'binding_id': binding,
        });
        // Native track changes can emit transitional snapshots. Read back the
        // real child engine until stable rather than trusting the command ack.
        Map<String, dynamic>? livePlayback;
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          final actual = await c.gateway.invoke(
            turn: '${turn.id}:verify',
            call: ModelToolCall('verify-$i', 'playback_get', '{}'),
            allowed: {'playback_get'},
            active: () => true,
            confirm: (_, _) async => false,
          );
          expect(actual.status, 'success');
          livePlayback = actual.data;
          if (['playing', 'paused'].contains(livePlayback['status'])) break;
        }
        debugPrint('FLOW playback readback: ${jsonEncode(livePlayback)}');
        expect(livePlayback!['status'], isIn(['playing', 'paused']));
        expect(
          livePlayback['duration_ms'] as num,
          inInclusiveRange(59000, 61000),
        );
        expect(livePlayback['subtitle'], {
          'kind': 'recognized',
          'binding_id': binding,
        });
        debugPrint(
          'FLOW VERIFIED: 60s clip saved, local subtitle bound and selected; tokens=${turn.tokens}',
        );
      } finally {
        // testWidgets disposes the tree before addTearDown callbacks. Restore
        // selection here while the coordinator and its database are alive.
        if (traceListener != null) c.removeListener(traceListener);
        c.stop();
        c.selectConversation(previousConversation);
      }
    },
    skip: !const bool.fromEnvironment('LIVE_ASSISTANT_FLOW'),
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
