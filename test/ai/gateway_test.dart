import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:openplayx/services/ai_tools/tool_registry.dart';

void main() {
  test('rejects malformed JSON, unknown tools, extra fields, bad numeric types and bounds', () async {
    var writes = 0;
    final registry = ToolRegistry()
      ..register(
        RegisteredTool(
          'seek',
          'seek',
          {
            'session_id': const ToolField('string', required: true),
            'position_ms': const ToolField(
              'integer',
              required: true,
              minimum: 0,
            ),
          },
          (_) async => {'count': ++writes},
          readOnly: false,
        ),
      );
    final gateway = ToolGateway(registry);
    for (final raw in [
      '{"session_id":',
      '[]',
      '{}',
      '{"session_id":"s","position_ms":0,"confirmed":true}',
      '{"session_id":"s","position_ms":-1}',
      '{"session_id":"s","position_ms":1.2}',
      '{"session_id":"","position_ms":0}',
    ]) {
      final result = await gateway.invoke(
        turn: 'turn',
        call: ModelToolCall('id', 'seek', raw),
        allowed: {'seek'},
        active: () => true,
        confirm: (_, _) async => true,
      );
      expect(result.status, 'failed');
    }
    final unknown = await gateway.invoke(
      turn: 'turn',
      call: const ModelToolCall('id', 'shell', '{}'),
      allowed: {'seek'},
      active: () => true,
      confirm: (_, _) async => true,
    );
    expect(unknown.error, 'unknownTool');
    final filtered = await gateway.invoke(
      turn: 'turn',
      call: const ModelToolCall(
        'id',
        'seek',
        '{"session_id":"s","position_ms":0}',
      ),
      allowed: {},
      active: () => true,
      confirm: (_, _) async => true,
    );
    expect(filtered.error, 'unknownTool');
    expect(writes, 0);
  });

  test('availability is checked again after host approval', () async {
    var enabled = true;
    var writes = 0;
    final registry = ToolRegistry()
      ..register(
        RegisteredTool(
          'write',
          'write',
          {},
          (_) async => {'writes': ++writes},
          available: () => enabled,
          readOnly: false,
          confirmation: true,
        ),
      );
    final result = await ToolGateway(registry).invoke(
      turn: 'turn',
      call: const ModelToolCall('id', 'write', '{}'),
      allowed: {'write'},
      active: () => true,
      confirm: (_, _) async {
        enabled = false;
        return true;
      },
    );
    expect(result.error, 'unavailable');
    expect(writes, 0);
  });

  test('unknown timed-out writes are not blindly replayed and errors are sanitized', () async {
    var writes = 0;
    final operation = Completer<Map<String, dynamic>>();
    final registry = ToolRegistry()
      ..register(
        RegisteredTool('write', 'write', {}, (_) {
          writes++;
          return operation.future;
        }, readOnly: false),
      );
    final gateway = ToolGateway(
      registry,
      timeout: const Duration(milliseconds: 10),
    );
    Future<ToolResult> invoke(String id) => gateway.invoke(
      turn: 'turn',
      call: ModelToolCall(id, 'write', '{}'),
      allowed: {'write'},
      active: () => true,
      confirm: (_, _) async => true,
    );
    expect((await invoke('one')).error, 'executionUnknown');
    final repeated = await invoke('two');
    expect(repeated.error, 'executionUnknown');
    expect(repeated.callId, 'two');
    expect(writes, 1);
    operation.complete({'ok': true});
  });
  test('a timed-out resolver cannot submit late effects, even while another turn is active', () async {
    var sideEffects = 0;
    var active = true;
    final resolved = Completer<void>();
    final registry = ToolRegistry()
      ..register(
        RegisteredTool('open', 'open', {}, (_) async {
          await resolved.future;
          if (ToolExecution.active) sideEffects++;
          return {'effects': sideEffects};
        }, readOnly: false),
      );
    final gateway = ToolGateway(
      registry,
      timeout: const Duration(milliseconds: 10),
    );
    final result = await gateway.invoke(
      turn: 'old',
      call: const ModelToolCall('id', 'open', '{}'),
      allowed: {'open'},
      active: () => active,
      confirm: (_, _) async => true,
    );
    expect(result.error, 'executionUnknown');
    active = false;
    active = true; // A later turn can be active while the old request unwinds.
    resolved.complete();
    await Future<void>.delayed(Duration.zero);
    expect(sideEffects, 0);
  });
  test('intervening writes create new intent so pause/resume/pause is not over-deduplicated', () async {
    var status = 'playing';
    var pauses = 0;
    final registry = ToolRegistry()
      ..register(
        RegisteredTool('pause', 'pause', {}, (_) async {
          pauses++;
          status = 'paused';
          return {'status': status};
        }, readOnly: false),
      )
      ..register(
        RegisteredTool('resume', 'resume', {}, (_) async {
          status = 'playing';
          return {'status': status};
        }, readOnly: false),
      );
    final gateway = ToolGateway(registry);
    for (final name in ['pause', 'resume', 'pause', 'pause']) {
      await gateway.invoke(
        turn: 'turn',
        call: ModelToolCall('id', name, '{}'),
        allowed: {'pause', 'resume'},
        active: () => true,
        confirm: (_, _) async => true,
      );
    }
    expect(pauses, 2);
    expect(status, 'paused');
  });
}
