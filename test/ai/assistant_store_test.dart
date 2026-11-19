import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/assistant/conversation/assistant_store.dart';
import 'package:openplayx/assistant/plugins/tools/tool_registry.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'new installs use platform; legacy custom settings retain their provider',
    () {
      final db = sqlite3.openInMemory(), configuration = sqlite3.openInMemory();
      addTearDown(db.close);
      addTearDown(configuration.close);
      final store = AssistantStore(db, configuration: configuration);
      final fresh = store.loadConfig();
      expect(fresh.usePlatform, true);
      expect(fresh.configured, true);
      expect(fresh.effectiveEndpoint, 'https://api.openplayx.com/v1/llm');
      expect(fresh.effectiveModel, 'llm');
      final legacy = AssistantConfig.fromJson({
        'endpoint': 'https://example.com/v1',
        'model': 'custom',
        'apiKey': 'secret',
      });
      expect(legacy.usePlatform, false);
      expect(legacy.effectiveEndpoint, 'https://example.com/v1');
      expect(legacy.configured, true);
    },
  );
  test(
    'credentials rotate outside SQLite and blank edit retains the existing key',
    () async {
      final db = sqlite3.openInMemory(), configuration = sqlite3.openInMemory();
      addTearDown(db.close);
      final store = AssistantStore(db, configuration: configuration);
      await store.saveConfig(
        const AssistantConfig(cloudAllowed: true),
        'FIRST_SECRET',
      );
      final first = store.loadConfig();
      expect(first.configured, isTrue);
      expect(first.toJson().toString(), isNot(contains('FIRST_SECRET')));
      expect(await store.key(first), 'FIRST_SECRET');
      // The key is kept on the assistant settings document itself.
      expect(
        configuration
            .select(
              "SELECT value_json FROM settings WHERE namespace='assistant'",
            )
            .single['value_json'],
        contains('"apiKey":"FIRST_SECRET"'),
      );
      await store.saveConfig(const AssistantConfig(), '');
      expect(await store.key(store.loadConfig()), 'FIRST_SECRET');
      await store.saveConfig(const AssistantConfig(), 'SECOND_SECRET');
      expect(await store.key(store.loadConfig()), 'SECOND_SECRET');
      expect(store.loadConfig().cloudAllowed, false);
    },
  );
  test('invalid endpoints cannot overwrite configured credentials', () async {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    final store = AssistantStore(db, configuration: sqlite3.openInMemory());
    await store.saveConfig(const AssistantConfig(), 'KEY');
    for (final endpoint in [
      'http://host/v1',
      'https://user:password@host/v1',
      'https://host?key=secret',
      'invalid',
    ]) {
      await expectLater(
        store.saveConfig(AssistantConfig(endpoint: endpoint), 'NEW'),
        throwsFormatException,
      );
    }
    expect(await store.key(store.loadConfig()), 'KEY');
  });
  test('plain http is accepted only for a model server on this device', () {
    for (final endpoint in [
      'http://localhost:11434/v1',
      'http://127.0.0.1:11434/v1',
      'http://[::1]:1234/v1',
    ]) {
      AssistantConfig(endpoint: endpoint).validate();
    }
    for (final endpoint in [
      'http://192.168.1.10:11434/v1',
      'http://10.0.2.2:11434/v1',
      'http://localhost.example.com/v1',
    ]) {
      expect(
        () => AssistantConfig(endpoint: endpoint).validate(),
        throwsFormatException,
      );
    }
  });
  test(
    'durable host operation journal prevents replay after Gateway recreation',
    () async {
      final db = sqlite3.openInMemory(), configuration = sqlite3.openInMemory();
      addTearDown(db.close);
      final store = AssistantStore(db, configuration: configuration);
      var writes = 0;
      final registry = ToolRegistry()
        ..register(
          RegisteredTool(
            'write',
            'write',
            {},
            (_) async => {'count': ++writes},
            readOnly: false,
          ),
        );
      Future<ToolResult> invoke(ToolGateway gateway, String call) =>
          gateway.invoke(
            turn: 'host-turn',
            call: ModelToolCall(call, 'write', '{}'),
            allowed: {'write'},
            active: () => true,
            confirm: (_, _) async => true,
          );
      await invoke(ToolGateway(registry, journal: store), 'first');
      final result = await invoke(
        ToolGateway(
          registry,
          journal: AssistantStore(db, configuration: sqlite3.openInMemory()),
        ),
        'new-vendor-id',
      );
      expect(result.callId, 'new-vendor-id');
      expect(result.data['count'], 1);
      expect(writes, 1);
      store.record('pending-operation', const ToolResult('id', 'pending'));
      expect(
        store.previous('pending-operation', 'id')!.error,
        'executionUnknown',
      );
    },
  );
}
