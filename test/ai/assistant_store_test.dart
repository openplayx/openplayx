import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/services/conversations/assistant_store.dart';
import 'package:openplayx/services/ai_tools/tool_registry.dart';
import 'package:openplayx/core/models/text_model.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'credentials rotate outside SQLite and blank edit retains the existing key',
    () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      final store = AssistantStore(db);
      await store.saveConfig(
        const AssistantConfig(cloudAllowed: true),
        'FIRST_SECRET',
      );
      final first = store.loadConfig();
      expect(first.credentialRef, startsWith('assistant.'));
      expect(await store.key(first), 'FIRST_SECRET');
      expect(
        db.select('SELECT value FROM assistant_config').first['value'],
        isNot(contains('FIRST_SECRET')),
      );
      await store.saveConfig(const AssistantConfig(), '');
      expect(await store.key(store.loadConfig()), 'FIRST_SECRET');
      await store.saveConfig(const AssistantConfig(), 'SECOND_SECRET');
      expect(await store.key(first), '');
      expect(await store.key(store.loadConfig()), 'SECOND_SECRET');
      expect(store.loadConfig().cloudAllowed, false);
    },
  );
  test('invalid endpoints cannot overwrite configured credentials', () async {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    final store = AssistantStore(db);
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
  test(
    'durable host operation journal prevents replay after Gateway recreation',
    () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      final store = AssistantStore(db);
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
        ToolGateway(registry, journal: AssistantStore(db)),
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
