// Live end-to-end check against a real model. Skipped unless .env has
// DEEPSEK_API_KEY. Run: flutter test test/ai/live_deepseek_test.dart
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/plugins/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_manager.dart';
import 'package:openplayx/plugins/model_langchain/langchain_model.dart';
import 'package:openplayx/services/ai_tools/media_tools.dart';
import 'package:openplayx/services/ai_tools/tool_registry.dart';
import 'package:openplayx/services/conversations/assistant_store.dart';
import 'package:openplayx/services/conversations/conversation_coordinator.dart';
import 'package:openplayx/services/library/library_service.dart';
import 'package:sqlite3/sqlite3.dart';

class NoSources extends SourceManager {
  @override
  List<SourceConfig> get configs => const [];
  @override
  Future<void> load() async {}
}

String? _key() {
  final file = File('.env');
  if (!file.existsSync()) return null;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('DEEPSEK_API_KEY=')) {
      final v = line.substring(16).replaceAll('"', '').trim();
      return v.isEmpty ? null : v;
    }
  }
  return null;
}

void main() {
  final key = _key();
  test(
    'DeepSeek pro: list library, pick one at random, open playback',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final library = LibraryService(sqlite3.openInMemory());
      final db = sqlite3.openInMemory();
      addTearDown(() {
        library.close();
        db.close();
      });
      final lib = library.create('电影');
      for (final title in ['星际穿越', '盗梦空间', '千与千寻', '肖申克的救赎', '霸王别姬']) {
        final id = library.register(
          SourceEntry(
            ResourceRef('@local', '/private/$title.mkv'),
            title,
            isFolder: false,
          ),
        );
        library.db.execute('INSERT INTO memberships VALUES (?,?,?)', [
          lib,
          id,
          1,
        ]);
      }

      final opened = <SourceEntry>[];
      late ConversationCoordinator coordinator;
      final tools = MediaTools(
        library: library,
        sources: NoSources(),
        context: () => {'page': 'home'},
        canExecute: () => coordinator.acceptingActions,
        playbackSnapshot: () => {'status': 'idle'},
        playbackControl: (_, _) async => {'status': 'idle'},
        openResource: (entry) async {
          opened.add(entry);
          return {
            'command_status': 'submitted',
            'playback': {'status': 'playing', 'session_id': 'p1'},
          };
        },
      );
      coordinator = ConversationCoordinator(
        store: AssistantStore(db),
        gateway: ToolGateway(tools.registry),
        context: () => {'page': 'home'},
        model: () async => LangChainModel(
          apiKey: key!,
          endpoint: 'https://api.deepseek.com',
          model: 'deepseek-v4-pro',
        ),
        requestTimeout: const Duration(seconds: 90),
        turnTimeout: const Duration(seconds: 240),
      );
      addTearDown(coordinator.dispose);

      await coordinator.send('看看我的媒体库里有什么，然后随机挑一个帮我播放。', toolsEnabled: true);

      final turn = coordinator.turns.single;
      for (final m in turn.messages) {
        final calls = m.calls.map((c) => '${c.name}(${c.arguments})').join(', ');
        // ignore: avoid_print
        print('[${m.role}] ${calls.isEmpty ? '' : 'CALLS: $calls  '}${m.text}');
      }
      // ignore: avoid_print
      print('status=${turn.status} error=${turn.error} tokens=${turn.tokens} '
          'opened=${opened.map((e) => e.name).toList()}');
      expect(turn.status, 'completed', reason: '${turn.error}');
      expect(opened, hasLength(1));
    },
    skip: key == null ? 'DEEPSEK_API_KEY not set in .env' : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
