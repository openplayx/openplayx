import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/assistant/conversation/assistant_store.dart';
import 'package:openplayx/features/assistant/controller/model_config_controller.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'platform default saves without a key and preserves custom settings',
    () async {
      final db = sqlite3.openInMemory(), configuration = sqlite3.openInMemory();
      addTearDown(db.close);
      addTearDown(configuration.close);
      final store = AssistantStore(db, configuration: configuration);
      final controller = ModelConfigController(store: store);
      addTearDown(controller.dispose);
      expect(controller.usePlatform, true);
      expect(await controller.save(), true);
      expect(store.loadConfig().configured, true);
      expect(await store.key(), isEmpty);
      controller.setUsePlatform(false);
      expect(controller.activeUsePlatform, true);
      expect(store.loadConfig().usePlatform, true);
      controller.endpoint.text = 'https://example.com/v1';
      controller.model.text = 'custom';
      controller.key.text = 'custom-secret';
      expect(await controller.save(), true);
      expect(controller.activeUsePlatform, false);
      controller.setUsePlatform(true);
      expect(controller.activeUsePlatform, false);
      expect(await controller.save(), true);
      expect(controller.activeUsePlatform, true);
      final restored = ModelConfigController(store: store);
      addTearDown(restored.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(restored.usePlatform, true);
      restored.setUsePlatform(false);
      expect(restored.endpoint.text, 'https://example.com/v1');
      expect(restored.model.text, 'custom');
      expect(restored.key.text, 'custom-secret');
      expect(await restored.save(), true);
      expect(store.loadConfig().usePlatform, false);
    },
  );

  test('a pasted full URL is reduced to the API base', () {
    expect(
      ModelConfigController.normalizeEndpoint(
        'https://api.example.com/v1/chat/completions',
      ),
      'https://api.example.com/v1',
    );
    expect(
      ModelConfigController.normalizeEndpoint('https://api.example.com/v1//'),
      'https://api.example.com/v1',
    );
  });

  test('saving a first configuration without a key asks for one', () async {
    final store = AssistantStore(
      sqlite3.openInMemory(),
      configuration: sqlite3.openInMemory(),
    );
    addTearDown(store.close);
    final controller = ModelConfigController(store: store);
    addTearDown(controller.dispose);
    controller.setUsePlatform(false);
    controller.endpoint.text = 'https://api.example.com/v1';
    controller.model.text = 'some-model';
    expect(await controller.save(), isFalse);
    expect(controller.result?.outcome, ModelConfigOutcome.keyRequired);
    expect(controller.busy, isFalse);

    controller.edited();
    expect(controller.result, isNull);
  });
}
