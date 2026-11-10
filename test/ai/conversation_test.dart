import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/services/ai_tools/tool_registry.dart';
import 'package:openplayx/services/conversations/assistant_store.dart';
import 'package:openplayx/services/conversations/conversation_coordinator.dart';
import 'package:sqlite3/sqlite3.dart';

class FakeModel implements TextModelCapability {
  FakeModel(this.respond);
  final Stream<ModelDelta> Function(ModelInferenceRequest) respond;
  final requests = <ModelInferenceRequest>[];
  @override
  Stream<ModelDelta> infer(ModelInferenceRequest request) {
    requests.add(request);
    return respond(request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late AssistantStore store;
  late ToolRegistry registry;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = sqlite3.openInMemory();
    store = AssistantStore(db);
    registry = ToolRegistry();
  });
  tearDown(() => db.close());
  ConversationCoordinator coordinator(
    TextModelCapability model, {
    int requests = 8,
    int calls = 12,
    Duration timeout = const Duration(seconds: 120),
  }) => ConversationCoordinator(
    store: store,
    gateway: ToolGateway(registry),
    model: () async => model,
    context: () => {'page': 'home'},
    maxRequests: requests,
    maxCalls: calls,
    turnTimeout: timeout,
  );

  test('pairs multiple call IDs with results, streams text, records actual usage and restores without replay', () async {
    var executions = 0;
    registry.register(
      RegisteredTool(
        'lookup',
        'lookup',
        {},
        (_) async => {'count': ++executions},
      ),
    );
    var round = 0;
    final fake = FakeModel((request) async* {
      if (round++ == 0) {
        yield const ModelToolDelta(ModelToolCall('a', 'lookup', '{}'));
        yield const ModelToolDelta(ModelToolCall('b', 'lookup', '{}'));
        yield const ModelCompleted('toolCalls', totalTokens: 10);
      } else {
        final results = request.messages
            .where((m) => m.role == 'tool')
            .toList();
        expect(results.map((m) => m.callId), ['a', 'b']);
        expect(jsonDecode(results[0].text)['data']['count'], 1);
        yield const ModelTextDelta('Found ');
        yield const ModelTextDelta('media');
        yield const ModelCompleted('stop', totalTokens: 5);
      }
    });
    final c = coordinator(fake);
    await c.send('Find media', toolsEnabled: true);
    expect(executions, 2);
    expect(c.turns.single.status, 'completed');
    expect(c.turns.single.messages.last.text, 'Found media');
    expect(c.turns.single.tokens, 15);
    c.dispose();
    final restored = coordinator(fake);
    expect(restored.turns.single.status, 'completed');
    expect(fake.requests.length, 2);
    restored.dispose();
  });

  test('only host confirmation authorizes writes; semantic duplicate call IDs execute once', () async {
    var executions = 0;
    registry.register(
      RegisteredTool(
        'save',
        'save',
        {'value': const ToolField('integer', required: true, minimum: 0)},
        (_) async => {'count': ++executions},
        readOnly: false,
        confirmation: true,
      ),
    );
    var round = 0;
    final fake = FakeModel((_) async* {
      if (round++ == 0) {
        yield const ModelToolDelta(ModelToolCall('one', 'save', '{"value":1}'));
        yield const ModelToolDelta(
          ModelToolCall('two', 'save', '{ "value" : 1 }'),
        );
        yield const ModelCompleted('toolCalls');
      } else {
        yield const ModelCompleted('stop');
      }
    });
    final c = coordinator(fake);
    final pending = c.send('Save', toolsEnabled: true);
    await Future<void>.delayed(Duration.zero);
    expect(c.confirmation?.tool, 'save');
    expect(executions, 0);
    c.decide(true);
    await pending;
    expect(executions, 1);
    expect(
      c.turns.single.messages
          .where((m) => m.role == 'tool')
          .map((m) => m.callId),
      ['one', 'two'],
    );
    c.dispose();
  });

  test('stop during stream cancels subscription and rejects late calls and concurrent input', () async {
    var executions = 0;
    var cancelled = false;
    registry.register(
      RegisteredTool(
        'write',
        'write',
        {},
        (_) async => {'count': ++executions},
        readOnly: false,
      ),
    );
    final events = StreamController<ModelDelta>(
      onCancel: () => cancelled = true,
    );
    final c = coordinator(FakeModel((_) => events.stream));
    final pending = c.send('first', toolsEnabled: true);
    await Future<void>.delayed(Duration.zero);
    await c.send('second', toolsEnabled: true);
    events.add(const ModelTextDelta('partial'));
    await Future<void>.delayed(Duration.zero);
    c.stop();
    events.add(const ModelToolDelta(ModelToolCall('late', 'write', '{}')));
    await pending;
    expect(cancelled, true);
    expect(executions, 0);
    expect(c.turns.length, 1);
    expect(c.turns.single.status, 'cancelled');
    expect(c.turns.single.messages.last.text, 'partial');
    await events.close();
    c.dispose();
  });

  test('cancel waiting confirmation prevents write', () async {
    var executions = 0;
    registry.register(
      RegisteredTool(
        'write',
        'write',
        {},
        (_) async => {'count': ++executions},
        readOnly: false,
        confirmation: true,
      ),
    );
    final c = coordinator(
      FakeModel((_) async* {
        yield const ModelToolDelta(ModelToolCall('id', 'write', '{}'));
        yield const ModelCompleted('toolCalls');
      }),
    );
    final pending = c.send('write', toolsEnabled: true);
    await Future<void>.delayed(Duration.zero);
    expect(c.confirmation, isNotNull);
    c.stop();
    await pending;
    expect(executions, 0);
    expect(c.turns.single.status, 'cancelled');
    c.dispose();
  });

  test(
    'incomplete stream cannot execute even a complete-looking call',
    () async {
      var executions = 0;
      registry.register(
        RegisteredTool(
          'write',
          'write',
          {},
          (_) async => {'count': ++executions},
        ),
      );
      final c = coordinator(
        FakeModel((_) async* {
          yield const ModelToolDelta(ModelToolCall('id', 'write', '{}'));
        }),
      );
      await c.send('write', toolsEnabled: true);
      expect(executions, 0);
      expect(c.turns.single.error, 'incompleteResponse');
      c.dispose();
    },
  );

  test('tool budget and model request limit bound repeated calls', () async {
    var executions = 0;
    registry.register(
      RegisteredTool('read', 'read', {}, (_) async => {'count': ++executions}),
    );
    final fake = FakeModel((_) async* {
      yield const ModelToolDelta(ModelToolCall('id', 'read', '{}'));
      yield const ModelCompleted('toolCalls');
    });
    final c = coordinator(fake, calls: 2);
    await c.send('loop', toolsEnabled: true);
    expect(executions, 2);
    expect(fake.requests.length, 3);
    expect(c.turns.single.error, 'toolBudget');
    c.dispose();
    final limited = coordinator(fake, requests: 1);
    await limited.send('loop', toolsEnabled: true);
    expect(limited.turns.last.error, 'requestBudget');
    limited.dispose();
  });

  test(
    'wall clock timeout also stops waiting for provider initialization',
    () async {
      final keyRead = Completer<TextModelCapability>();
      final c = ConversationCoordinator(
        store: store,
        gateway: ToolGateway(registry),
        model: () => keyRead.future,
        context: () => {},
        turnTimeout: const Duration(milliseconds: 15),
      );
      await c.send('hello', toolsEnabled: true);
      expect(c.turns.single.error, 'turnTimeout');
      expect(c.busy, false);
      c.dispose();
    },
  );

  test('persisted interrupted calls are displayed but excluded from new request history', () async {
    store.saveTurn('old', 'running', [
      const ModelMessage(
        'assistant',
        '',
        calls: [ModelToolCall('a', 'write', '{}')],
      ),
    ]);
    final reopened = AssistantStore(db);
    final fake = FakeModel((request) async* {
      expect(request.messages.any((m) => m.calls.isNotEmpty), false);
      yield const ModelTextDelta('OK');
      yield const ModelCompleted('stop');
    });
    final c = ConversationCoordinator(
      store: reopened,
      gateway: ToolGateway(registry),
      model: () async => fake,
      context: () => {},
    );
    expect(c.turns.first.status, 'interrupted');
    await c.send('new', toolsEnabled: false);
    expect(fake.requests.single.tools, isEmpty);
    c.dispose();
  });
}
