// Acceptance test of the whole assistant movie flow against live services:
// a local Ollama model, the test VM's movie SMB share, the bundled FFmpeg,
// local whisper (tiny) and the desktop player window. The App runs on a
// scratch data directory seeded here, never on the user's configuration.
// Every service is required: a missing one fails the test. Creates a clip in
// the share's OpenPlayX folder. Desktop only; run with `flutter drive` (child
// windows need their entrypoint arguments), see integration_test/README.md.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openplayx/app/app.dart';
import 'package:openplayx/app/debug_seed/debug_seed.dart';
import 'package:openplayx/app/player_window.dart';
import 'package:openplayx/capabilities/speech/asr_model_store.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/data/configuration/configuration_database.dart';
import 'package:openplayx/features/assistant/view/ai_chat_view.dart';
import 'package:openplayx/ui/adaptive/assistant_action.dart';

import 'support/live_services.dart';

const movieFlowPrompt =
    '从 SMB 的 movie 共享里随便挑一部电影（不要总选第一个），用 media_probe 看时长，'
    '在 10%-80% 之间选起点截取 60 秒，用 media_transcode 生成子视频，'
    '完成后用 media_save_to_source 存回 SMB，'
    '对存回去的子视频用 subtitle_generate（本地识别）生成字幕并用 subtitle_save 保存，'
    '然后用 playback_open 打开这个子视频，再用 playback_set_subtitle 选上刚保存的字幕。'
    '每一步以工具结果为准；任务还没完成就告诉我进度并停下。';

final _data = Directory('${Directory.systemTemp.path}/openplayx-it-movie-flow');
const _asrModel = 'whisper-tiny-multilingual';

/// Fails unless Ollama serves [ollamaModel] at [ollamaEndpoint].
Future<void> _requireOllama() async {
  final uri = Uri.parse(ollamaEndpoint);
  await requireReachable('Ollama', uri.host, uri.port);
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(
      Uri.parse('$ollamaEndpoint/models'),
    )).close();
    final body = jsonDecode(await utf8.decodeStream(response)) as Map;
    final models = [for (final m in body['data'] as List) (m as Map)['id']];
    if (!models.contains(ollamaModel) &&
        !models.contains('$ollamaModel:latest')) {
      fail(
        'Ollama has no model $ollamaModel (has $models). '
        'Run `make integration-ollama`.',
      );
    }
  } finally {
    client.close(force: true);
  }
}

/// A fresh App data directory with the tiny whisper model installed and the
/// model, movie share and local recognition configured through the debug
/// seed (the same import path settings use).
Future<void> _prepareAppData() async {
  if (_data.existsSync()) _data.deleteSync(recursive: true);
  final spec = asrModelSpec(_asrModel)!;
  final model = File('$asrModelDirectory/${spec.file}');
  if (!model.existsSync() ||
      await AsrModelStore.sha256File(model) != spec.sha256) {
    fail(
      '${model.path} is required (whisper.cpp ${spec.file}, '
      'sha256 ${spec.sha256}). Run `make integration-defines`.',
    );
  }
  final models = Directory('${_data.path}/asr_models')
    ..createSync(recursive: true);
  model.copySync('${models.path}/${spec.file}');
  File('${models.path}/models.json').writeAsStringSync(
    jsonEncode({
      spec.id: {
        'file': spec.file,
        'sha256': spec.sha256,
        'bytes': spec.bytes,
        'license': spec.license,
        'verified_at': DateTime.now().toUtc().toIso8601String(),
      },
    }),
  );
  final seed = {
    'version': 1,
    'sources': [
      {
        'id': 'it-movie-smb',
        'kind': 'smb',
        'name': 'SMB movie',
        'address': movieSmbAddress,
        'username': movieSmbUser,
        'secret': movieSmbPassword,
      },
    ],
    'asr': [
      {
        'id': 'embedded',
        'kind': 'embedded',
        'name': 'On device',
        'modelId': _asrModel,
      },
    ],
    'assistant': {
      'endpoint': ollamaEndpoint,
      'model': ollamaModel,
      'cloudAllowed': true,
      'toolsSupported': true,
      'maxTokens': 8192,
      // Ollama ignores the key; the App requires one to call the model.
      'apiKey': 'ollama',
    },
  };
  final db = await ConfigurationDatabase.open();
  try {
    final report = await DebugSeed.apply(db, jsonEncode(seed), force: true);
    if (report.failed.isNotEmpty) fail('Seed failed: $report');
  } finally {
    db.close();
  }
}

Future<void> main([List<String> args = const []]) async {
  // Main and child engines share one scratch data directory, not the user's.
  useAppDataDirectory(_data);
  // Desktop child engines use this same entrypoint; run their real player.
  if (await runPlayerWindowIfRequested(args)) return;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('local model completes SMB clip, local subtitles and playback', (
    tester,
  ) async {
    requireDefines({
      'OLLAMA_ENDPOINT': ollamaEndpoint,
      'OLLAMA_MODEL': ollamaModel,
      'MOVIE_SMB_ADDRESS': movieSmbAddress,
      'MOVIE_SMB_USER': movieSmbUser,
      'MOVIE_SMB_PASSWORD': movieSmbPassword,
      'ASR_MODEL_DIR': asrModelDirectory,
    });
    await _requireOllama();
    await requireReachable(
      'Movie SMB share',
      Uri.parse(movieSmbAddress).host,
      445,
    );
    await _prepareAppData();
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
      final binding = (results[savedSubtitle.id]!['data'] as Map)['binding_id'];
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
  }, timeout: const Timeout(Duration(minutes: 30)));
}
