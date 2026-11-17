import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/assistant/conversation/assistant_store.dart';
import 'package:openplayx/features/assistant/controller/model_config_controller.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
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
    controller.endpoint.text = 'https://api.example.com/v1';
    controller.model.text = 'some-model';
    expect(await controller.save(), isFalse);
    expect(controller.result?.outcome, ModelConfigOutcome.keyRequired);
    expect(controller.busy, isFalse);

    controller.edited();
    expect(controller.result, isNull);
  });
}
